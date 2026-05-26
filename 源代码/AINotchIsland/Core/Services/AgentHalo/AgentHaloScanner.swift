import Foundation
internal import AppKit

struct AgentDefinition {
    let name: String
    let source: String
    let agentType: AgentType
    var processPatterns: [String] = []
    var bundleIdentifiers: [String] = []
    var appNamePrefixes: [String] = []
    var port: UInt16? = nil
    var pidFile: String? = nil
    var hookSupport: HookSupport = .none
    var configPaths: [String] = []
}

struct DetectedAgentProcess {
    let pid: Int32
    let source: String
    let definition: AgentDefinition
    var childCommands: [String] = []
    var isActive: Bool { !childCommands.isEmpty }
}

final class AgentHaloScanner {
    private let state: AgentHaloState
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.ayanami.ai-notch-island.scanner", qos: .utility)
    private var lastActivity: [String: String] = [:]
    // Cached cwd per pid. Resolved off the main thread; reused across
    // ticks so we don't re-run lsof every second.
    private var cwdCache: [Int32: String] = [:]
    private var cwdInFlight: Set<Int32> = []

    private static let activeScanInterval: TimeInterval = 1.0
    private static let idleScanInterval: TimeInterval = 2.0
    private static let staleSessionTimeout: TimeInterval = 3

    private static let ignoredChildPatterns: Set<String> = [
        "ps", "pgrep", "bash", "zsh", "sh", "fish", "login",
        "agent-halo-bridge", "sleep", "cat", "tee",
        "codex", "claude", "amp", "openclaw-gateway", "hermes",
        "gemini", "aider", "opencode", "kiro", "mimo",
        "kiro-cli-chat", "kiro-cli", "kiro_cli_desktop",
        "Google Chrome", "Chromium", "firefox",
        "caffeinate", "sourcekit-lsp", "clangd", "swift-frontend",
        "Autoupdate", "Updater"
    ]

    private static let ignoredChildSubstrings: [String] = [
        "Helper", "helper", "crashpad_handler", "app-server",
        "gpu-process", "renderer", "utility",
        "Electron Framework", "tui.js", "fig_input_method",
        "sourcekit-lsp", "Sparkle", "Autoupdate",
        "XcodeDefault.xctoolchain", "caffeinate"
    ]

    private static let internalProcessIndicators: [String] = [
        "app-server", "--listen stdio", "--analytics",
        "Sparkle.framework", "Autoupdate", "updater",
        "gateway run", "node_repl", "crashpad_handler"
    ]

    var registry: [AgentDefinition] {
        AgentRegistry.shared.allDefinitions
    }

    init(state: AgentHaloState) {
        self.state = state
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: Self.activeScanInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let snapshot = self.takeProcessSnapshot()
            DispatchQueue.main.async {
                self.processScanResults(snapshot: snapshot)
            }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func killProcess(for session: AgentSession) {
        if let pid = session.pid {
            kill(pid, SIGTERM)
        } else {
            let source = session.id.replacingOccurrences(of: "scan-", with: "")
            guard let def = registry.first(where: { $0.source == source }) else { return }
            queue.async {
                for pattern in def.processPatterns {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                    proc.arguments = ["-f", pattern]
                    proc.standardOutput = FileHandle.nullDevice
                    proc.standardError = FileHandle.nullDevice
                    try? proc.run()
                    proc.waitUntilExit()
                }
            }
        }
    }

    // MARK: - Main Scan Loop

    private func processScanResults(snapshot: [ProcessInfo]) {
        let runningApps = NSWorkspace.shared.runningApplications
        let defs = registry
        var detectedAgents: [DetectedAgentProcess] = []

        // Path 1: CLI agents detected via process patterns (require shell → terminal chain)
        for agent in defs where !agent.processPatterns.isEmpty {
            if let pids = findAgentPIDs(agent, snapshot: snapshot), !pids.isEmpty {
                for pid in pids {
                    let children = getActiveChildCommands(parentPid: pid, snapshot: snapshot)
                    var detected = DetectedAgentProcess(
                        pid: pid,
                        source: agent.source,
                        definition: agent,
                        childCommands: children
                    )
                    _ = detected.isActive
                    detectedAgents.append(detected)
                }
            }
        }

        // Deduplicate: if any ancestor is also a detected agent, skip the descendant
        let allDetectedPids = Set(detectedAgents.map(\.pid))
        detectedAgents.removeAll { detected in
            var current = detected.pid
            var depth = 0
            while depth < 10 {
                guard let proc = snapshot.first(where: { $0.pid == current }) else { break }
                if proc.ppid <= 1 || proc.ppid == current { break }
                if allDetectedPids.contains(proc.ppid) { return true }
                current = proc.ppid
                depth += 1
            }
            return false
        }

        let oldRunning = self.state.runningAgents
        var newRunning = Set<String>()

        for detected in detectedAgents {
            // A process is "orphaned" when we can't trace it back to a
            // shell+terminal — typically launchd-adopted after the
            // owning terminal exited (ppid == 1) and the user has long
            // since moved on. We log it for diagnostics but don't surface
            // it on the island: the user did not knowingly start it in
            // this session, so showing it as "active" is misleading.
            guard let termApp = self.detectParentTerminal(pid: detected.pid, snapshot: snapshot, runningApps: runningApps) else {
                DebugLogWriter.shared.append("[Scanner] orphan agent ignored: pid=\(detected.pid) source=\(detected.source) cmd=\(snapshot.first(where: { $0.pid == detected.pid })?.command ?? "?")\n")
                continue
            }

            let scanId = "scan-\(detected.source)-\(detected.pid)"
            let isActive = detected.isActive
            newRunning.insert(scanId)

            self.upsertSession(scanId: scanId, isActive: isActive, detected: detected, termApp: termApp)
        }

        // Path 2: Desktop app agents detected via bundleIdentifiers or appNamePrefixes (visible window apps only)
        for agent in defs where !agent.bundleIdentifiers.isEmpty || !agent.appNamePrefixes.isEmpty {
            guard let app = runningApps.first(where: { app in
                guard !app.isTerminated, app.activationPolicy == .regular else { return false }
                if let bundle = app.bundleIdentifier, agent.bundleIdentifiers.contains(bundle) {
                    return true
                }
                if let name = app.localizedName {
                    return agent.appNamePrefixes.contains(where: { name.hasPrefix($0) })
                }
                return false
            }) else { continue }

            let scanId = "scan-\(agent.source)-app"
            newRunning.insert(scanId)

            let appName = app.localizedName ?? agent.name
            if let idx = self.state.sessions.firstIndex(where: { $0.id == scanId }) {
                self.state.sessions[idx].processDetected = true
                self.state.sessions[idx].lastProcessSeen = Date()
                self.state.sessions[idx].lastUpdated = Date()
            } else {
                var session = AgentSession(
                    id: scanId,
                    agentType: agent.agentType,
                    status: .idle,
                    title: agent.name,
                    processDetected: true,
                    connectionType: .scanned,
                    lastProcessSeen: Date(),
                    startedAt: Date(),
                    lastUpdated: Date(),
                    terminalInfo: AgentTerminalInfo(terminalApp: appName)
                )
                session.pid = app.processIdentifier
                self.state.addSession(session)
            }
        }

        self.state.runningAgents = newRunning

        // Immediately remove sessions for processes that no longer exist
        for scanId in oldRunning where !newRunning.contains(scanId) {
            self.removeSession(scanId: scanId)
        }

        self.cleanupStaleSessions()
        self.adjustScanInterval()
    }

    private func upsertSession(scanId: String, isActive: Bool, detected: DetectedAgentProcess, termApp: String) {
        let cwd = self.cwdCache[detected.pid]
        if cwd == nil { self.resolveCwd(forPid: detected.pid) }
        if let idx = self.state.sessions.firstIndex(where: { $0.id == scanId }) {
            self.state.sessions[idx].processDetected = true
            self.state.sessions[idx].lastProcessSeen = Date()
            self.state.sessions[idx].lastUpdated = Date()
            if let cwd, self.state.sessions[idx].terminalInfo?.workingDirectory != cwd {
                self.state.sessions[idx].terminalInfo?.workingDirectory = cwd
            }
            if isActive {
                let activity = self.summarizeActivity(detected.childCommands, source: detected.source)
                self.state.sessions[idx].status = .working
                self.state.sessions[idx].workingOn = activity
                self.lastActivity[scanId] = activity
            } else if self.state.sessions[idx].status == .working {
                self.state.sessions[idx].status = .idle
                self.state.sessions[idx].workingOn = nil
            }
        } else {
            let status: AgentSessionStatus = isActive ? .working : .idle
            let activity = isActive ? self.summarizeActivity(detected.childCommands, source: detected.source) : nil
            var session = AgentSession(
                id: scanId,
                agentType: detected.definition.agentType,
                status: status,
                title: detected.definition.name,
                workingOn: activity,
                processDetected: true,
                connectionType: .scanned,
                lastProcessSeen: Date(),
                startedAt: Date(),
                lastUpdated: Date(),
                terminalInfo: AgentTerminalInfo(terminalApp: termApp, workingDirectory: cwd)
            )
            session.pid = detected.pid
            self.state.addSession(session)
            if isActive { self.lastActivity[scanId] = activity }
        }
    }

    /// Resolve cwd off the main thread and feed it back so the next scan
    /// tick can pick it up. We never block the scanner with a sync `lsof`.
    private func resolveCwd(forPid pid: Int32) {
        guard !cwdInFlight.contains(pid) else { return }
        cwdInFlight.insert(pid)
        queue.async { [weak self] in
            let resolved = AgentHaloScanner.runLsofCwd(pid: pid)
            DispatchQueue.main.async {
                guard let self else { return }
                self.cwdInFlight.remove(pid)
                if let resolved {
                    self.cwdCache[pid] = resolved
                    // Backfill any existing session for this pid right away.
                    for idx in self.state.sessions.indices where self.state.sessions[idx].pid == pid {
                        if self.state.sessions[idx].terminalInfo?.workingDirectory != resolved {
                            self.state.sessions[idx].terminalInfo?.workingDirectory = resolved
                        }
                    }
                }
            }
        }
    }

    private static func runLsofCwd(pid: Int32) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8) else { return nil }
            for line in output.split(separator: "\n") where line.hasPrefix("n") {
                return String(line.dropFirst())
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Process Detection (Single Snapshot)

    private struct ProcessInfo {
        let pid: Int32
        let ppid: Int32
        let command: String
    }

    private func takeProcessSnapshot() -> [ProcessInfo] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-eo", "pid,ppid,command"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return [] }
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            var results: [ProcessInfo] = []
            for line in output.split(separator: "\n").dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.split(separator: " ", maxSplits: 2)
                guard parts.count >= 3,
                      let pid = Int32(parts[0]),
                      let ppid = Int32(parts[1]) else { continue }
                results.append(ProcessInfo(pid: pid, ppid: ppid, command: String(parts[2])))
            }
            return results
        } catch {
            return []
        }
    }

    private func findAgentPIDs(_ agent: AgentDefinition, snapshot: [ProcessInfo]) -> [Int32]? {
        var pids: [Int32] = []

        for pattern in agent.processPatterns {
            // Reuse a compiled NSRegularExpression instead of recompiling
            // every scanner tick. The scanner runs once per second across
            // ~22 agent defs × multiple patterns each; profiling showed
            // 70%+ of CPU was spent in NSRegularExpression instantiation
            // and ICU re-matching against the ~700-line ps snapshot.
            let regex = Self.regexCache.get(pattern: pattern)
            guard let regex else { continue }
            for proc in snapshot {
                let range = NSRange(proc.command.startIndex..., in: proc.command)
                if regex.firstMatch(in: proc.command, range: range) != nil {
                    if proc.ppid <= 1 { continue }
                    if Self.internalProcessIndicators.contains(where: { proc.command.contains($0) }) { continue }
                    // Skip browser/app helper processes that happen to match pattern via arguments
                    if Self.ignoredChildSubstrings.contains(where: { proc.command.contains($0) }) { continue }
                    pids.append(proc.pid)
                }
            }
        }

        return pids.isEmpty ? nil : Array(Set(pids))
    }

    /// Thread-safe cache of compiled NSRegularExpressions keyed by their
    /// source pattern. Compiling a regex is expensive — once per pattern
    /// is enough for the entire app lifetime.
    private final class RegexCache: @unchecked Sendable {
        private let lock = NSLock()
        private var cache: [String: NSRegularExpression] = [:]

        func get(pattern: String) -> NSRegularExpression? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cache[pattern] { return cached }
            guard let new = try? NSRegularExpression(pattern: pattern, options: []) else {
                return nil
            }
            cache[pattern] = new
            return new
        }
    }
    private static let regexCache = RegexCache()

    // MARK: - Parent Terminal Detection

    private static let shellNames: Set<String> = ["zsh", "bash", "sh", "fish", "dash", "tcsh", "ksh"]

    private func detectParentTerminal(pid: Int32, snapshot: [ProcessInfo], runningApps: [NSRunningApplication]) -> String? {
        let appPidMap = Dictionary(
            runningApps.compactMap { app -> (Int32, String)? in
                guard let name = app.localizedName, !app.isTerminated else { return nil }
                return (app.processIdentifier, name)
            },
            uniquingKeysWith: { first, _ in first }
        )

        guard let proc = snapshot.first(where: { $0.pid == pid }) else { return nil }
        var current = proc.ppid
        var depth = 0
        var foundShell = false
        while depth < 15 {
            guard current > 1 else { break }
            if let ancestor = snapshot.first(where: { $0.pid == current }) {
                let baseName = (ancestor.command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ancestor.command)
                let leaf = (baseName as NSString).lastPathComponent
                if Self.shellNames.contains(leaf) || leaf.hasPrefix("-") && Self.shellNames.contains(String(leaf.dropFirst())) {
                    foundShell = true
                }
            }
            if let appName = appPidMap[current], foundShell {
                return appName
            }
            guard let ancestor = snapshot.first(where: { $0.pid == current }) else { break }
            if ancestor.ppid == current { break }
            current = ancestor.ppid
            depth += 1
        }
        return nil
    }

    // MARK: - Child Process Activity Detection (Snapshot-based)

    private func getActiveChildCommands(parentPid: Int32, snapshot: [ProcessInfo], depth: Int = 0) -> [String] {
        guard depth < 5 else { return [] }
        let children = snapshot.filter { $0.ppid == parentPid }
        guard !children.isEmpty else { return [] }

        var commands: [String] = []
        for child in children {
            let base = extractBaseName(child.command)
            let baseLower = base.lowercased()
            let isIgnored = Self.ignoredChildPatterns.contains(base)
                || Self.ignoredChildPatterns.contains(baseLower)
                || Self.ignoredChildSubstrings.contains(where: { child.command.contains($0) })
            if !isIgnored {
                commands.append(child.command)
            }
            commands.append(contentsOf: getActiveChildCommands(parentPid: child.pid, snapshot: snapshot, depth: depth + 1))
        }
        return commands
    }

    private func extractBaseName(_ command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1)
        guard let first = parts.first else { return command }
        let path = String(first)
        return (path as NSString).lastPathComponent
    }

    // MARK: - Activity Summarization

    private func summarizeActivity(_ commands: [String], source: String) -> String {
        guard let primary = commands.first else { return "Active" }

        let base = extractBaseName(primary)

        switch base {
        case "node", "npx", "tsx", "ts-node":
            let script = extractArg(primary)
            return script.map { "\(base): \($0)" } ?? base
        case "python", "python3":
            let script = extractArg(primary)
            return script.map { "python: \($0)" } ?? "python"
        case "git":
            return "git \(extractSubcommand(primary))"
        case "npm", "yarn", "pnpm", "bun":
            return "\(base) \(extractSubcommand(primary))"
        case "cargo", "go", "rustc", "gcc", "make", "cmake":
            return "\(base) \(extractSubcommand(primary))"
        case "curl", "wget":
            return "network request"
        case "rg", "grep", "find", "fd":
            return "searching"
        case "sed", "awk":
            return "text processing"
        default:
            let short = primary.prefix(60)
            return short.count < primary.count ? "\(short)…" : primary
        }
    }

    private func extractArg(_ command: String) -> String? {
        let parts = command.split(separator: " ")
        for part in parts.dropFirst() {
            let s = String(part)
            if !s.hasPrefix("-") { return (s as NSString).lastPathComponent }
        }
        return nil
    }

    private func extractSubcommand(_ command: String) -> String {
        let parts = command.split(separator: " ")
        guard parts.count > 1 else { return "" }
        return String(parts[1])
    }

    // MARK: - Scan Interval Adjustment

    private func adjustScanInterval() {
        let hasActive = state.activeSessions.contains { $0.connectionType == .scanned }
        let interval = hasActive ? Self.activeScanInterval : Self.idleScanInterval
        timer?.schedule(deadline: .now() + interval, repeating: interval)
    }

    // MARK: - Session Lifecycle

    private func removeSession(scanId: String) {
        if let pid = state.sessions.first(where: { $0.id == scanId })?.pid {
            cwdCache.removeValue(forKey: pid)
        }
        state.sessions.removeAll { $0.id == scanId && $0.connectionType == .scanned }
        lastActivity.removeValue(forKey: scanId)
        state.recalculateGlobalStatus()
    }

    private func cleanupStaleSessions() {
        let now = Date()
        state.sessions.removeAll { session in
            (session.status == .done || session.status == .idle) &&
            session.connectionType == .scanned &&
            now.timeIntervalSince(session.lastUpdated) > Self.staleSessionTimeout
        }
    }

}
