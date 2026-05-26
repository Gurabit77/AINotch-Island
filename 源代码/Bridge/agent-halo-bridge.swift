import Foundation

// Agent Halo Bridge
// Receives hook events from multiple coding agents on stdin, normalizes them,
// and forwards to Agent Halo socket server

let socketPath = NSHomeDirectory() + "/.agent-halo/run/agent-halo.sock"
let responsesDir = NSHomeDirectory() + "/.agent-halo/run/responses"
let source: String = {
    if let idx = CommandLine.arguments.firstIndex(of: "--source"), idx + 1 < CommandLine.arguments.count {
        return CommandLine.arguments[idx + 1]
    }
    return "claude"
}()
let isBlocking = CommandLine.arguments.contains("--blocking")

// Read all stdin
var inputData = Data()
while let line = readLine(strippingNewline: false) {
    inputData.append(line.data(using: .utf8) ?? Data())
}

guard !inputData.isEmpty else { exit(0) }

// Parse the hook event JSON
guard let hookInput = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
    exit(0)
}

// Extract hook type based on source agent format
let rawHookType: String
switch source {
case "cursor":
    // Cursor doesn't send hook_event_name in JSON; the hook name is implicit
    // from which hook entry fired. We check known Cursor fields to infer type.
    rawHookType = hookInput["hook_event_name"] as? String
        ?? hookInput["hookName"] as? String
        ?? hookInput["event"] as? String
        ?? inferCursorHookType(hookInput)
case "codex":
    // Codex uses same schema as Claude Code
    rawHookType = hookInput["hook_event_name"] as? String
        ?? hookInput["hook_type"] as? String
        ?? hookInput["type"] as? String ?? "Unknown"
default:
    // Claude Code / Hermes / generic
    rawHookType = hookInput["hook_event_name"] as? String
        ?? hookInput["hook_type"] as? String
        ?? hookInput["type"] as? String ?? "Unknown"
}

let sessionId = hookInput["session_id"] as? String ?? UUID().uuidString
let toolName = hookInput["tool_name"] as? String ?? ""
let toolInput = hookInput["tool_input"] as? [String: Any] ?? [:]

// Build our normalized event
var event: [String: Any] = [
    "type": mapHookType(rawHookType, source: source),
    "sessionId": sessionId,
    "timestamp": Date().timeIntervalSince1970,
    "agent": source
]

// Build payload based on normalized hook type
var payload: [String: Any] = [
    "terminalApp": detectTerminal(),
    "workingDirectory": hookInput["cwd"] as? String ?? FileManager.default.currentDirectoryPath
]
// The bridge is invoked as a child of the agent process (e.g. claude /
// codex / mimo). Walking up our ppid chain lets us identify the actual
// agent pid so the app can deduplicate hooked sessions against
// scanner-discovered ones — without this, the same real process appears
// as two cards (one hooked, one scanned) because their session ids
// belong to different namespaces.
if let agentPid = findAgentPID(source: source) {
    payload["pid"] = agentPid
}
let normalizedType = mapHookType(rawHookType, source: source)

switch normalizedType {
case "PreToolUse":
    let tool = toolName.isEmpty ? (hookInput["tool_name"] as? String ?? "") : toolName
    payload["tool"] = tool
    payload["command"] = toolInput["command"] as? String ?? hookInput["command"] as? String
    payload["filePath"] = toolInput["file_path"] as? String ?? toolInput["filePath"] as? String
        ?? hookInput["file_path"] as? String ?? hookInput["filePath"] as? String
    let desc = payload["command"] as? String ?? payload["filePath"] as? String ?? ""
    let toolLabel = tool.isEmpty ? "Working" : tool
    payload["workingOn"] = "\(toolLabel): \(desc)"

case "PostToolUse":
    payload["tool"] = toolName.isEmpty ? (hookInput["tool_name"] as? String ?? "") : toolName
    payload["status"] = "completed"

case "PermissionRequest":
    payload["tool"] = toolName
    payload["title"] = "请求权限: \(toolName)"
    payload["description"] = toolInput["description"] as? String ?? hookInput["description"] as? String ?? ""
    payload["command"] = toolInput["command"] as? String ?? hookInput["command"] as? String
    payload["filePath"] = toolInput["file_path"] as? String ?? toolInput["filePath"] as? String
        ?? hookInput["file_path"] as? String ?? hookInput["filePath"] as? String

    if let oldStr = toolInput["old_string"] as? String, let newStr = toolInput["new_string"] as? String {
        payload["oldContent"] = oldStr
        payload["newContent"] = newStr
    }
    if let content = toolInput["content"] as? String, let fp = payload["filePath"] as? String {
        payload["newContent"] = content
        payload["title"] = "写入: \(fp)"
    }

    if let q = hookInput["question"] as? String ?? toolInput["question"] as? String {
        payload["question"] = q
        payload["title"] = q
    }
    if let opts = hookInput["options"] as? [[String: Any]] ?? toolInput["options"] as? [[String: Any]] {
        payload["options"] = opts
    }
    if let multi = hookInput["isMultiSelect"] as? Bool ?? toolInput["isMultiSelect"] as? Bool {
        payload["isMultiSelect"] = multi
    }

    // AskUserQuestion ships its content under `questions: [{question, options, multiSelect}]`
    // (plural). Map the first entry into the same single-question payload so
    // the app's existing renderer keeps working. We pick [0] because that's
    // the prompt the CLI is blocking on right now; if more arrive later we
    // can extend to surface a list, but for now one prompt per approval.
    if payload["question"] == nil,
       let questions = (toolInput["questions"] as? [[String: Any]])
        ?? (hookInput["questions"] as? [[String: Any]]),
       let first = questions.first {
        if let q = first["question"] as? String {
            payload["question"] = q
            payload["title"] = q
        }
        if let opts = first["options"] as? [[String: Any]] {
            payload["options"] = opts
        }
        if let multi = first["multiSelect"] as? Bool ?? first["isMultiSelect"] as? Bool {
            payload["isMultiSelect"] = multi
        }
    }

    payload["riskLevel"] = classifyRisk(tool: toolName, command: payload["command"] as? String)

case "SessionStart":
    payload["title"] = sourceDisplayName(source)
    payload["terminalApp"] = detectTerminal()
    payload["workingDirectory"] = hookInput["cwd"] as? String ?? FileManager.default.currentDirectoryPath

case "SessionEnd":
    payload["status"] = "done"

case "UserPromptSubmit":
    payload["status"] = "working"
    if let prompt = hookInput["prompt"] as? String {
        payload["workingOn"] = String(prompt.prefix(500))
    }

case "SubagentStart":
    payload["subAgentCount"] = 1

case "Stop":
    payload["status"] = "stopped"

default:
    break
}

event["payload"] = payload

let toolLower = (toolName.isEmpty ? (hookInput["tool_name"] as? String ?? "") : toolName).lowercased()

// Synthesize question/options for tools that have CLI-native prompts not exposed via hook JSON
if normalizedType == "PermissionRequest" && toolLower == "exitplanmode" && payload["question"] == nil {
    payload["question"] = "Plan ready. How to proceed?"
    payload["options"] = [
        ["id": "1", "label": "Yes, auto-accept edits", "description": "Approve plan, auto-accept subsequent edits"],
        ["id": "2", "label": "Yes, manually approve edits", "description": "Approve plan, review each edit"],
        ["id": "3", "label": "Tell Claude what to change", "description": "Reject plan, provide feedback"]
    ] as [[String: Any]]
    payload["title"] = "Plan Approval"
    event["payload"] = payload
}

// Determine if this is a question/choice prompt (AskUserQuestion, ExitPlanMode with options)
// vs a regular tool permission (Bash, Edit, Read) that CLI should handle itself
let isQuestionPrompt: Bool = {
    if normalizedType != "PermissionRequest" { return false }
    // Has explicit question/options fields → choice prompt
    if payload["question"] != nil || payload["options"] != nil { return true }
    // AskUserQuestion tool → choice prompt
    if toolLower == "askuserquestion" || toolLower == "elicitation" { return true }
    return false
}()

if isBlocking && isQuestionPrompt {
    // Timeout: if no response in 120s, exit silently so CLI falls back to terminal prompt
    DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
        unlink(responsesDir + "/\(sessionId).pipe")
        exit(0)
    }
    // Question/choice prompt: block and forward to app for user selection
    let fm = FileManager.default
    try? fm.createDirectory(atPath: responsesDir, withIntermediateDirectories: true)
    let pipePath = responsesDir + "/\(sessionId).pipe"
    unlink(pipePath)
    guard mkfifo(pipePath, 0o644) == 0 else { exit(1) }
    sendToSocket(event: event)
    guard let fh = FileHandle(forReadingAtPath: pipePath) else {
        unlink(pipePath)
        exit(1)
    }
    let data = fh.readDataToEndOfFile()
    fh.closeFile()
    unlink(pipePath)
    if !data.isEmpty, let responseStr = String(data: data, encoding: .utf8) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let action = json["action"] as? String {
            switch action {
            case "allow", "approve":
                print("{\"decision\":\"allow\"}")
            case "deny", "reject":
                print("{\"decision\":\"deny\"}")
            case "alwaysAllow":
                print("{\"decision\":\"alwaysAllow\"}")
            case "answer":
                // For ExitPlanMode: map selected option to allow/deny
                if toolLower == "exitplanmode" {
                    let selected = json["selectedOptions"] as? [String] ?? []
                    if selected.contains("3") {
                        print("{\"decision\":\"deny\"}")
                    } else {
                        print("{\"decision\":\"allow\"}")
                    }
                } else if let opts = json["selectedOptions"] {
                    let optsData = try? JSONSerialization.data(withJSONObject: opts)
                    let optsStr = optsData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                    print("{\"decision\":\"answer\",\"selectedOptions\":\(optsStr)}")
                } else {
                    print("{\"decision\":\"answer\"}")
                }
            default:
                print("{\"decision\":\"\(action)\"}")
            }
        } else {
            print(responseStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    exit(0)
} else {
    // PreToolUse + AskUserQuestion: Claude Code's AskUserQuestion tool
    // interacts directly with the terminal — it does NOT go through
    // PermissionRequest and is not interruptable by hooks the normal
    // way. To still surface the question on the island, we:
    //   1. Send a synthetic "info" approval event so the island can
    //      render the question + options for the user to read.
    //   2. Reply with a PreToolUse `deny` decision so Claude abandons
    //      the AskUserQuestion call and instead asks the same question
    //      as a regular assistant message — which the user can answer
    //      by typing in the terminal as normal.
    // The island card is dismissed by a separate UserPromptSubmit hook
    // firing in the app (see NotchAgentHaloEventsHandler).
    if normalizedType == "PreToolUse" && toolLower == "askuserquestion" {
        // Extract questions[0] same way the PermissionRequest path does.
        var question: String? = nil
        var options: [[String: Any]] = []
        var isMulti = false
        if let questions = (toolInput["questions"] as? [[String: Any]])
            ?? (hookInput["questions"] as? [[String: Any]]),
           let first = questions.first {
            question = first["question"] as? String
            options = first["options"] as? [[String: Any]] ?? []
            isMulti = (first["multiSelect"] as? Bool) ?? (first["isMultiSelect"] as? Bool) ?? false
        }

        if let q = question {
            // Override the event so the app renders an AskUserQuestion info card.
            var infoPayload = payload
            infoPayload["tool"] = toolName
            infoPayload["title"] = q
            infoPayload["question"] = q
            infoPayload["options"] = options
            infoPayload["isMultiSelect"] = isMulti
            infoPayload["askUserQuestionInfo"] = true
            var infoEvent = event
            infoEvent["type"] = "PermissionRequest"
            infoEvent["payload"] = infoPayload
            sendToSocket(event: infoEvent)
        } else {
            // No parseable question → just notify normally without the card.
            sendToSocket(event: event)
        }

        // Tell Claude to abandon AskUserQuestion and ask in plain text.
        let denyJSON: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "用户希望以自由文本回复。请以常规对话消息重新提问，等待回复。"
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: denyJSON),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
        exit(0)
    }

    // Regular tool permission or non-blocking: just forward event to app for monitoring, don't block CLI
    sendToSocket(event: event)
}

// MARK: - Source-specific helpers

func inferCursorHookType(_ input: [String: Any]) -> String {
    // Cursor hooks don't always include a type field; we infer from available fields
    if input["shell_command"] != nil || input["command"] != nil {
        return "beforeShellExecution"
    }
    if input["mcp_tool"] != nil || input["mcp_server"] != nil {
        return "beforeMCPExecution"
    }
    if input["file_path"] != nil && input["edit"] != nil {
        return "afterFileEdit"
    }
    if input["thought"] != nil {
        return "afterAgentThought"
    }
    if input["response"] != nil || input["assistant_response"] != nil {
        return "afterAgentResponse"
    }
    if input["user_prompt"] != nil || input["prompt"] != nil {
        return "beforeSubmitPrompt"
    }
    return "Unknown"
}

func mapHookType(_ type: String, source: String = "") -> String {
    // Cursor-specific event names
    switch type {
    case "beforeSubmitPrompt": return "UserPromptSubmit"
    case "beforeShellExecution": return "PreToolUse"
    case "beforeMCPExecution": return "PreToolUse"
    case "beforeReadFile": return "PreToolUse"
    case "afterShellExecution": return "PostToolUse"
    case "afterMCPExecution": return "PostToolUse"
    case "afterFileEdit": return "PostToolUse"
    case "afterAgentThought": return "PreToolUse"
    case "afterAgentResponse": return "Stop"
    case "stop": return "Stop"
    // Standard event names (Claude Code, Codex, Hermes)
    case "PreToolUse": return "PreToolUse"
    case "PostToolUse": return "PostToolUse"
    case "PermissionRequest": return "PermissionRequest"
    case "SessionStart": return "SessionStart"
    case "SessionEnd": return "SessionEnd"
    case "UserPromptSubmit": return "UserPromptSubmit"
    case "Stop": return "Stop"
    case "SubagentStart": return "PreToolUse"
    case "SubagentStop": return "PostToolUse"
    default: return type
    }
}

func sourceDisplayName(_ source: String) -> String {
    switch source {
    case "claude": return "Claude Code"
    case "codex": return "Codex"
    case "cursor": return "Cursor"
    case "hermes": return "Hermes"
    case "openclaw": return "OpenClaw"
    case "gemini": return "Gemini CLI"
    default: return source.capitalized
    }
}

func classifyRisk(tool: String, command: String?) -> String {
    let highRisk = ["rm ", "git push", "git reset", "DROP ", "DELETE ", "sudo"]
    if let cmd = command {
        for pattern in highRisk where cmd.contains(pattern) {
            return "High"
        }
    }
    if tool == "Bash" { return "Medium" }
    return "Low"
}

func detectTerminal() -> String {
    if let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"] {
        return termProgram
    }
    return "Terminal"
}

/// Walks up the parent process chain from ourselves looking for a process
/// whose command line names the requesting agent (claude / codex / mimo /
/// hermes / etc). Returns that pid so the Halo app can match this hook
/// event against the same process discovered by its process scanner.
///
/// The bridge is launched as a child of the agent's shell-hook execution.
/// Typical chain on Claude Code: agent-halo-bridge → /bin/sh -c → claude.
/// We stop at ppid 1 (launchd) or after a small fixed depth.
func findAgentPID(source: String) -> Int32? {
    let patterns = agentProcessPatterns(source: source)
    guard !patterns.isEmpty else { return nil }

    // Build a single ps snapshot once — calling ps repeatedly per ancestor
    // would be many fork/exec on the agent's hot hook path.
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/bin/ps")
    proc.arguments = ["-eo", "pid=,ppid=,command="]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    guard (try? proc.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard let output = String(data: data, encoding: .utf8) else { return nil }

    var byPid: [Int32: (ppid: Int32, command: String)] = [:]
    for line in output.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 3,
              let pid = Int32(parts[0]),
              let ppid = Int32(parts[1]) else { continue }
        byPid[pid] = (ppid, String(parts[2]))
    }

    var current = getppid()
    var depth = 0
    while current > 1 && depth < 10 {
        guard let entry = byPid[current] else { return nil }
        let cmd = entry.command
        for pattern in patterns {
            if cmd.range(of: pattern, options: .regularExpression) != nil {
                // Skip our own bridge / wrapper shells, they're not the agent.
                if cmd.contains("agent-halo-bridge") {
                    break
                }
                if cmd.hasPrefix("/bin/sh") || cmd.hasPrefix("-zsh") || cmd.hasPrefix("/bin/zsh") || cmd.hasPrefix("/bin/bash") {
                    break
                }
                return current
            }
        }
        current = entry.ppid
        depth += 1
    }
    return nil
}

/// Process-name regex fragments per agent. Mirrors the AgentRegistry
/// `processPatterns` used by the app-side scanner so both sides converge
/// on the same pid.
func agentProcessPatterns(source: String) -> [String] {
    switch source {
    case "claude", "claude-code", "claude_code":
        return ["\\bclaude\\b", "/claude$", "node .*/claude"]
    case "codex":
        return ["\\bcodex\\b", "/codex "]
    case "mimo":
        return ["\\bmimo\\b", "/mimo$", "node .*/mimo"]
    case "hermes":
        return ["hermes_cli", "/hermes$"]
    case "amp":
        return ["\\bamp\\b"]
    case "kiro":
        return ["kiro-cli", "kiro_cli"]
    case "cursor":
        return ["\\bcursor\\b"]
    case "openclaw", "open-claw":
        return ["openclaw"]
    default:
        return ["\\b\(source)\\b"]
    }
}


func sendToSocket(event: [String: Any]) {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: event),
          var jsonString = String(data: jsonData, encoding: .utf8) else {
        exit(0)
    }
    jsonString += "\n"

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { exit(0) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = socketPath.utf8CString
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        let raw = UnsafeMutableRawPointer(ptr)
        pathBytes.withUnsafeBufferPointer { buf in
            raw.copyMemory(from: buf.baseAddress!, byteCount: min(buf.count, 104))
        }
    }

    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
    let connectResult = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
            connect(fd, sockPtr, addrLen)
        }
    }

    guard connectResult == 0 else {
        close(fd)
        exit(0)
    }

    jsonString.withCString { cstr in
        _ = send(fd, cstr, strlen(cstr), 0)
    }

    close(fd)
}
