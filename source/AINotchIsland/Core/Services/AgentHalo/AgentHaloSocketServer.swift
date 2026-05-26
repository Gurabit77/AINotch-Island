import Foundation
import Combine
import os.log

final class AgentHaloSocketServer: ObservableObject {
    private let state: AgentHaloState
    private let adapterRegistry: AdapterRegistry
    var conversationMonitor: ConversationMonitor?
    var gitStatusMonitor: GitStatusMonitor?
    private var serverFd: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]
    // Per-fd session bookkeeping. Bridges are short-lived (one process per
    // hook event), so EOF on a fd does NOT mean "agent session ended" —
    // this map is kept only so we GC its entries cleanly on disconnect and
    // could be wired to a future heartbeat-based liveness signal. Owned
    // by the main queue: only mutate inside DispatchQueue.main.async.
    private var sessionsByClientFd: [Int32: Set<String>] = [:]
    private let queue = DispatchQueue(label: "com.ayanami.agent-halo.socket", qos: .userInitiated)
    private let socketPath: String

    var onApprovalAutoResolved: ((String) -> Void)?

    @Published var isListening = false
    @Published var connectedClientCount = 0
    @Published var totalEventsReceived = 0
    @Published var lastEventTime: Date?
    @Published var lastError: String?

    init(state: AgentHaloState, adapterRegistry: AdapterRegistry = .shared) {
        self.state = state
        self.adapterRegistry = adapterRegistry
        let runDir = NSHomeDirectory() + "/.agent-halo/run"
        self.socketPath = runDir + "/agent-halo.sock"
    }

    func start() {
        setupDirectory()
        startWithRetry()
    }

    private func startWithRetry(attempts: Int = 3) {
        startUnixSocket()
        if !isListening && attempts > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.setupDirectory()
                self?.startWithRetry(attempts: attempts - 1)
            }
        }
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        for (fd, source) in clientSources {
            source.cancel()
            Darwin.close(fd)
        }
        clientSources.removeAll()
        clientBuffers.removeAll()
        sessionsByClientFd.removeAll()
        if serverFd >= 0 {
            Darwin.close(serverFd)
            serverFd = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
        DispatchQueue.main.async {
            self.isListening = false
            self.connectedClientCount = 0
        }
    }

    private func setupDirectory() {
        let runDir = (socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: runDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    private func startUnixSocket() {
        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            AppLogger.socket.error("Failed to create socket: \(errno)")
            return
        }

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
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFd, sockPtr, addrLen)
            }
        }

        guard bindResult == 0 else {
            let err = errno
            AppLogger.socket.error("Bind failed: \(err)")
            DispatchQueue.main.async { self.lastError = "Socket bind failed (errno: \(err))" }
            Darwin.close(serverFd)
            serverFd = -1
            return
        }

        guard listen(serverFd, 10) == 0 else {
            let err = errno
            AppLogger.socket.error("Listen failed: \(err)")
            DispatchQueue.main.async { self.lastError = "Socket listen failed (errno: \(err))" }
            Darwin.close(serverFd)
            serverFd = -1
            return
        }

        let flags = fcntl(serverFd, F_GETFL)
        _ = fcntl(serverFd, F_SETFL, flags | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: serverFd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.serverFd, fd >= 0 {
                Darwin.close(fd)
                self?.serverFd = -1
            }
        }
        source.resume()
        acceptSource = source

        DispatchQueue.main.async { self.isListening = true }
        AppLogger.socket.info("Unix socket listening at \(self.socketPath)")
    }

    private func acceptConnection() {
        var clientAddr = sockaddr_un()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                accept(serverFd, sockPtr, &clientAddrLen)
            }
        }

        guard clientFd >= 0 else { return }

        let flags = fcntl(clientFd, F_GETFL)
        _ = fcntl(clientFd, F_SETFL, flags | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.readFromClient(fd: clientFd)
        }
        source.setCancelHandler {
            Darwin.close(clientFd)
        }
        source.resume()
        clientSources[clientFd] = source
        // Snapshot count on the same queue that owns the dict, then hand
        // the integer (a value type) to main. NEVER let main read
        // `clientSources` directly — it lives on socket queue.
        let snapshot = clientSources.count
        DispatchQueue.main.async { self.connectedClientCount = snapshot }
    }

    private func readFromClient(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = read(fd, &buffer, buffer.count)

        if bytesRead <= 0 {
            clientSources[fd]?.cancel()
            clientSources.removeValue(forKey: fd)
            clientBuffers.removeValue(forKey: fd)
            // Bridges are short-lived: one process per hook event. The fd
            // EOF after every event is normal — it does NOT mean the agent
            // session ended. So we ONLY garbage-collect the per-fd tracking
            // dict here; the session state must stay untouched. Lifecycle
            // closure for hooked sessions is driven by explicit SessionEnd
            // events and by transcript/process death detection elsewhere.
            let snapshot = clientSources.count
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sessionsByClientFd.removeValue(forKey: fd)
                self.connectedClientCount = snapshot
            }
            return
        }

        if clientBuffers[fd] == nil { clientBuffers[fd] = Data() }
        clientBuffers[fd]!.append(contentsOf: buffer[..<bytesRead])

        guard let text = String(data: clientBuffers[fd]!, encoding: .utf8) else { return }

        let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
        let hasTrailingNewline = text.hasSuffix("\n")
        let completeLines = hasTrailingNewline ? parts.dropLast() : parts.dropLast()
        let remainder = hasTrailingNewline ? "" : String(parts.last ?? "")

        for line in completeLines where !line.isEmpty {
            guard let lineData = line.data(using: .utf8) else { continue }
            do {
                let event = try JSONDecoder().decode(AgentHookEvent.self, from: lineData)
                self.appendDebugLog("[AgentHalo] \(Date()) Decoded: \(event.type.rawValue) \(event.sessionId)\n")
                DispatchQueue.main.async { [weak self] in
                    self?.handleEvent(event, clientFd: fd)
                }
            } catch {
                self.appendDebugLog("[AgentHalo] \(Date()) DECODE ERROR: \(error)\n  line: \(line)\n")
                AppLogger.socket.error("JSON decode error: \(error.localizedDescription)")
            }
        }

        clientBuffers[fd] = remainder.data(using: .utf8) ?? Data()
    }

    private func handleEvent(_ event: AgentHookEvent, clientFd: Int32) {
        totalEventsReceived += 1
        lastEventTime = Date()
        appendDebugLog("[AgentHalo] \(Date()) handleEvent: \(event.type.rawValue) \(event.sessionId) agent=\(event.agent ?? "nil")\n")

        let agentType = resolveAgentType(event.agent)
        let adapter = adapterRegistry.adapter(for: agentType)
        let transformed = adapter?.transformPayload(event) ?? event

        // Track which fd is producing this sessionId so we can force-end
        // every session if the producing client disappears (kill -9 of the
        // bridge, terminal close, network drop, etc).
        if transformed.type != .sessionEnd {
            sessionsByClientFd[clientFd, default: []].insert(transformed.sessionId)
        }

        switch transformed.type {
        case .sessionStart:
            handleSessionStart(transformed)
        case .sessionEnd:
            sessionsByClientFd[clientFd]?.remove(transformed.sessionId)
            handleSessionEnd(transformed, adapter: adapter)
        case .stop:
            state.updateSession(id: transformed.sessionId, status: .interrupted)
        case .userPromptSubmit:
            ensureSession(for: transformed)
            autoResolveStaleApprovals(for: transformed.sessionId)
            state.updateSession(id: transformed.sessionId, status: .working)
        case .preToolUse:
            handlePreToolUse(transformed)
        case .postToolUse:
            handlePostToolUse(transformed)
        case .permissionRequest:
            handlePermissionRequest(transformed)
        }
    }

    /// Called the moment a client fd closes. Force-ends every session that
    /// was producing events through that fd. This is what kills ghost cards
    /// when bridge crashes or `kill -9` claude — we don't wait for an
    /// idle-cleanup timeout, the kernel told us the producer is gone.
    private func handleClientDisconnect(sessions orphaned: Set<String>) {
        guard !orphaned.isEmpty else { return }
        appendDebugLog("[AgentHalo] client fd closed, ending \(orphaned.count) hooked session(s)\n")
        for sessionId in orphaned {
            guard let idx = state.sessions.firstIndex(where: { $0.id == sessionId }) else { continue }
            // Don't override a session that was already cleanly ended.
            if state.sessions[idx].status != .done {
                state.updateSession(id: sessionId, status: .done)
            }
            conversationMonitor?.stopMonitoring(sessionId: sessionId)
            gitStatusMonitor?.stopMonitoring(sessionId: sessionId)
        }
    }

    func sendApprovalResponse(sessionId: String, requestId: String, response: AgentApprovalResponse) -> AdapterResponseResult {
        guard let session = state.sessions.first(where: { $0.id == sessionId }) else {
            return .failed(AdapterError.transportUnavailable)
        }
        guard let adapter = adapterRegistry.adapter(for: session.agentType) else {
            return .unsupported
        }
        guard adapter.capabilities.contains(.approvalResponse) else {
            return .unsupported
        }
        return adapter.sendApprovalResponse(sessionId: sessionId, requestId: requestId, response: response)
    }

    private func resolveAgentType(_ source: String?) -> AgentType {
        guard let source = source?.lowercased() else { return .unknown }
        switch source {
        case "claude", "claude-code", "claude_code": return .claudeCode
        case "claude-desktop": return .claudeDesktop
        case "codex": return .codex
        case "cursor": return .cursor
        case "gemini", "gemini-cli": return .geminiCLI
        case "copilot": return .copilot
        case "deepseek": return .deepSeek
        case "hermes": return .hermes
        case "openclaw", "open-claw": return .openClaw
        case "opencode", "open-code": return .openCode
        case "amp": return .amp
        case "kiro": return .kiro
        case "windsurf": return .windsurf
        case "aider": return .aider
        case "trae": return .trae
        case "chatgpt": return .chatGPT
        default: return AgentType(rawValue: source) ?? .unknown
        }
    }

    private func handleSessionStart(_ event: AgentHookEvent) {
        let agent = resolveAgentType(event.agent)
        var terminalInfo: AgentTerminalInfo?
        if let payload = event.payload, let app = payload.terminalApp {
            terminalInfo = AgentTerminalInfo(
                terminalApp: app,
                windowId: payload.windowId,
                tabId: payload.tabId,
                paneId: payload.paneId,
                workingDirectory: payload.workingDirectory
            )
        }
        var session = AgentSession(
            id: event.sessionId,
            agentType: agent,
            status: .starting,
            title: event.payload?.title ?? agent.displayName,
            workingOn: event.payload?.workingOn,
            connectionType: .hooked,
            startedAt: Date(timeIntervalSince1970: event.timestamp),
            lastUpdated: Date(),
            terminalInfo: terminalInfo
        )
        session.pid = event.payload?.pid
        state.addSession(session)
        conversationMonitor?.startMonitoring(sessionId: event.sessionId)
        if let dir = event.payload?.workingDirectory {
            gitStatusMonitor?.startMonitoring(sessionId: event.sessionId, directory: dir)
        }
    }

    private func handleSessionEnd(_ event: AgentHookEvent, adapter: AgentAdapter? = nil) {
        let status: AgentSessionStatus = event.payload?.status == "error" ? .error : .done
        if let tokenUsage = adapter?.extractTokenUsage(from: event),
           let idx = state.sessions.firstIndex(where: { $0.id == event.sessionId }) {
            state.sessions[idx].tokenUsage = tokenUsage
        }
        state.updateSession(id: event.sessionId, status: status)
        conversationMonitor?.stopMonitoring(sessionId: event.sessionId)
        gitStatusMonitor?.stopMonitoring(sessionId: event.sessionId)
    }

    private func ensureSession(for event: AgentHookEvent) {
        if let idx = state.sessions.firstIndex(where: { $0.id == event.sessionId }) {
            if state.sessions[idx].terminalInfo == nil, let app = event.payload?.terminalApp, !app.isEmpty {
                state.sessions[idx].terminalInfo = AgentTerminalInfo(
                    terminalApp: app,
                    workingDirectory: event.payload?.workingDirectory
                )
                state.sessions[idx].connectionType = .hooked
            }
            if state.sessions[idx].pid == nil, let pid = event.payload?.pid {
                state.sessions[idx].pid = pid
            }
            return
        }
        let agent = resolveAgentType(event.agent)
        var terminalInfo: AgentTerminalInfo?
        if let app = event.payload?.terminalApp, !app.isEmpty {
            terminalInfo = AgentTerminalInfo(
                terminalApp: app,
                workingDirectory: event.payload?.workingDirectory
            )
        }
        var session = AgentSession(
            id: event.sessionId,
            agentType: agent,
            status: .working,
            title: agent == .unknown ? (event.agent ?? "Agent") : agent.displayName,
            workingOn: event.payload?.workingOn,
            connectionType: .hooked,
            startedAt: Date(timeIntervalSince1970: event.timestamp),
            lastUpdated: Date(),
            terminalInfo: terminalInfo
        )
        session.pid = event.payload?.pid
        state.addSession(session)
        conversationMonitor?.startMonitoring(sessionId: event.sessionId)
    }

    private func handlePreToolUse(_ event: AgentHookEvent) {
        ensureSession(for: event)
        autoResolveStaleApprovals(for: event.sessionId)
        guard let idx = state.sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        state.sessions[idx].status = .working

        let toolName = event.payload?.tool ?? "Unknown"
        let record = ToolCallRecord(
            tool: toolName,
            command: event.payload?.command,
            filePath: event.payload?.filePath,
            timestamp: Date(),
            status: .running
        )
        state.sessions[idx].toolHistory.append(record)
        if state.sessions[idx].toolHistory.count > 20 {
            state.sessions[idx].toolHistory.removeFirst()
        }

        if let workingOn = event.payload?.workingOn {
            state.sessions[idx].workingOn = workingOn
        }
        if let tool = event.payload?.tool {
            state.sessions[idx].workingOn = "\(tool): \(event.payload?.filePath ?? event.payload?.command ?? "")"
        }
        state.sessions[idx].lastUpdated = Date()
    }

    private func handlePostToolUse(_ event: AgentHookEvent) {
        ensureSession(for: event)
        guard let idx = state.sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        state.sessions[idx].lastUpdated = Date()
        if let count = event.payload?.subAgentCount {
            state.sessions[idx].subAgentCount = count
        }
        if let lastIdx = state.sessions[idx].toolHistory.lastIndex(where: { $0.status == .running }) {
            state.sessions[idx].toolHistory[lastIdx].status = .completed
        }
    }

    private func handlePermissionRequest(_ event: AgentHookEvent) {
        guard let payload = event.payload else {
            appendDebugLog("[AgentHalo] PermissionRequest DROPPED: no payload for \(event.sessionId)\n")
            return
        }
        appendDebugLog("[AgentHalo] PermissionRequest processing: session=\(event.sessionId) tool=\(payload.tool ?? "nil")\n")
        ensureSession(for: event)
        let requestId = "\(event.sessionId)-\(UUID().uuidString.prefix(8))"

        var diff: AgentDiffContent?
        if let oldContent = payload.oldContent, let newContent = payload.newContent, let filePath = payload.filePath {
            diff = AgentDiffContent(
                filePath: filePath,
                oldContent: oldContent,
                newContent: newContent,
                hunks: parseDiff(old: oldContent, new: newContent)
            )
        }

        var question: AgentQuestionContent?
        if let q = payload.question, let opts = payload.options {
            question = AgentQuestionContent(
                question: q,
                options: opts.map { AgentQuestionOption(id: $0.id, label: $0.label, description: $0.description) },
                isMultiSelect: payload.isMultiSelect ?? false
            )
        }

        let riskLevel = classifyRisk(tool: payload.tool, command: payload.command)

        let approvalType: AgentApprovalType
        if payload.askUserQuestionInfo == true {
            approvalType = .askUserQuestionInfo
        } else if question != nil {
            approvalType = .question
        } else {
            approvalType = .permission
        }

        let approval = AgentApprovalRequest(
            id: requestId,
            sessionId: event.sessionId,
            type: approvalType,
            title: payload.title ?? payload.tool ?? "Permission Request",
            description: payload.description ?? "",
            riskLevel: riskLevel,
            toolName: payload.tool,
            filePath: payload.filePath,
            diff: diff,
            bashCommand: payload.command,
            question: question,
            createdAt: Date()
        )

        state.addApproval(approval)
        appendDebugLog("[AgentHalo] approval added: \(approval.id) globalStatus=\(state.globalStatus)\n")
    }

    private func autoResolveStaleApprovals(for sessionId: String) {
        let stale = state.pendingApprovals.filter { $0.sessionId == sessionId }
        for approval in stale {
            state.resolveApproval(id: approval.id, response: .allow)
            onApprovalAutoResolved?(approval.id)
        }
    }

    private func classifyRisk(tool: String?, command: String?) -> AgentRiskLevel {
        let highRiskCommands = ["rm ", "git push", "git reset", "DROP ", "DELETE ", "sudo"]
        if let command {
            for pattern in highRiskCommands {
                if command.contains(pattern) { return .high }
            }
        }
        if tool == "Bash" { return .medium }
        return .low
    }

    private func parseDiff(old: String, new: String) -> [AgentDiffHunk] {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var lines: [AgentDiffLine] = []
        var i = 0, j = 0

        while i < oldLines.count || j < newLines.count {
            if i < oldLines.count && j < newLines.count && oldLines[i] == newLines[j] {
                lines.append(AgentDiffLine(type: .context, content: oldLines[i], lineNumber: j + 1))
                i += 1; j += 1
            } else {
                if i < oldLines.count && (j >= newLines.count || !newLines.contains(oldLines[i])) {
                    lines.append(AgentDiffLine(type: .deletion, content: oldLines[i], lineNumber: i + 1))
                    i += 1
                } else if j < newLines.count {
                    lines.append(AgentDiffLine(type: .addition, content: newLines[j], lineNumber: j + 1))
                    j += 1
                }
            }
        }

        return [AgentDiffHunk(oldStart: 1, oldCount: oldLines.count, newStart: 1, newCount: newLines.count, lines: lines)]
    }

    private func appendDebugLog(_ msg: String) {
        DebugLogWriter.shared.append(msg)
    }
}
