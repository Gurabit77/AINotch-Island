import SwiftUI
import Combine

@MainActor
final class AgentHaloViewModel: ObservableObject {
    @Published var event: AgentHaloEvent?

    let state: AgentHaloState
    let socketServer: AgentHaloSocketServer
    let scanner: AgentHaloScanner
    let transcriptWatcher: TranscriptWatcher
    let conversationMonitor = ConversationMonitor()
    let gitStatusMonitor = GitStatusMonitor()
    let devServerMonitor = DevServerMonitor()

    private var cancellables = Set<AnyCancellable>()
    private var previousStatus: AgentGlobalStatus = .idle
    private var knownSessionIDs: Set<String> = []
    private var knownApprovalIDs: Set<String> = []
    private var lastWorkingOnMap: [String: String] = [:]

    init(state: AgentHaloState) {
        self.state = state
        self.socketServer = AgentHaloSocketServer(state: state)
        self.scanner = AgentHaloScanner(state: state)
        self.transcriptWatcher = TranscriptWatcher(state: state)
        observeState()
    }

    let hookInstaller = HookInstaller.shared
    let hotkeyManager = AgentHaloHotkeyManager.shared

    let notificationService = NotificationService.shared

    func startServices() {
        hookInstaller.setupIfNeeded()
        socketServer.conversationMonitor = conversationMonitor
        socketServer.gitStatusMonitor = gitStatusMonitor
        socketServer.onApprovalAutoResolved = { [weak self] requestId in
            DispatchQueue.main.async {
                self?.event = .approvalResolved(requestId: requestId)
            }
        }
        socketServer.start()
        observeSocketErrors()
        scanner.start()
        transcriptWatcher.start()
        devServerMonitor.start()
        // Daily sweep of orphaned AI agent processes (long-dead terminals
        // whose CLI was adopted by launchd). Runs at most once per 24h.
        OrphanAgentCleaner.shared.start()
        setupHotkeys()
        notificationService.requestPermission()
        state.loadPersistedHistory()
        state.startIdleCleanupTimer()
        MenuBarStatusController.shared.setup(viewModel: self)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.event = .agentsActive
            for session in self?.state.activeSessions ?? [] {
                self?.conversationMonitor.startMonitoring(sessionId: session.id)
                if let dir = session.terminalInfo?.workingDirectory {
                    self?.gitStatusMonitor.startMonitoring(sessionId: session.id, directory: dir)
                }
            }
        }
    }

    func stopServices() {
        socketServer.stop()
        scanner.stop()
        transcriptWatcher.stop()
        devServerMonitor.stop()
        OrphanAgentCleaner.shared.stop()
        hotkeyManager.stop()
    }

    private func observeSocketErrors() {
        socketServer.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.event = .terminalJumpFailed(error)
            }
            .store(in: &cancellables)
    }

    private func handleNewApproval(_ approval: AgentApprovalRequest) {
        self.event = .approvalRequested(requestId: approval.id)
        let agentName = self.state.sessions.first { $0.id == approval.sessionId }?.agentType.displayName ?? "Agent"
        self.notificationService.notifyApproval(approval, agentName: agentName)
    }

    func respondToApproval(requestId: String, action: AgentApprovalResponse) {
        appendDebugLog("[VM] respondToApproval: \(requestId) action=\(action)\n")
        if let approval = state.pendingApprovals.first(where: { $0.id == requestId }) {
            let result = socketServer.sendApprovalResponse(
                sessionId: approval.sessionId,
                requestId: requestId,
                response: action
            )
            appendDebugLog("[VM] sendApprovalResponse result=\(result) session=\(approval.sessionId)\n")
        } else {
            appendDebugLog("[VM] respondToApproval: approval not found in pendingApprovals\n")
        }
        state.resolveApproval(id: requestId, response: action)
        event = .approvalResolved(requestId: requestId)
    }

    func killSession(_ session: AgentSession) {
        scanner.killProcess(for: session)
        state.updateSession(id: session.id, status: .done)
    }

    func jumpToTerminal(for session: AgentSession) -> Bool {
        guard let info = session.terminalInfo else {
            event = .terminalJumpFailed("No terminal info")
            return false
        }
        TerminalJumpEngine.shared.jump(to: info) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                break
            case .appNotFound:
                self.event = .terminalJumpFailed("Terminal not found")
            case .scriptError(let msg):
                self.event = .terminalJumpFailed(msg)
            }
        }
        return true
    }

    private func observeState() {
        state.$globalStatus
            .removeDuplicates()
            .sink { [weak self] newStatus in
                guard let self else { return }
                let oldStatus = self.previousStatus
                self.previousStatus = newStatus
                self.appendDebugLog("[VM] globalStatus: \(oldStatus) → \(newStatus)\n")
                self.event = .statusChanged(newStatus)

                if oldStatus == .idle && newStatus != .idle {
                    SoundManager.shared.play(.sessionStart)
                    self.event = .agentsActive
                } else if newStatus == .idle && oldStatus != .idle {
                    self.event = .agentsIdle
                }

                if newStatus == .waitingApproval, let approval = self.state.pendingApprovals.last {
                    self.handleNewApproval(approval)
                }

                if newStatus == .error, let session = self.state.sessions.first(where: { $0.status == .error }) {
                    SoundManager.shared.play(.taskError)
                    self.notificationService.notifyError(session: session, message: "Session encountered an error")
                }
            }
            .store(in: &cancellables)

        // Observe each new approval directly (not just globalStatus transitions)
        state.$pendingApprovals
            .sink { [weak self] approvals in
                guard let self else { return }
                guard let latest = approvals.last else { return }
                if !self.knownApprovalIDs.contains(latest.id) {
                    self.knownApprovalIDs.insert(latest.id)
                    self.appendDebugLog("[VM] new approval detected: \(latest.id) type=\(latest.type)\n")
                    self.handleNewApproval(latest)
                }
            }
            .store(in: &cancellables)

        state.$sessions
            .map { sessions in
                sessions.contains {
                    $0.status == .working || $0.status == .starting || $0.status == .waitingApproval ||
                    ($0.processDetected && $0.status != .done)
                }
            }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] hasActive in
                guard let self else { return }
                if hasActive {
                    self.appendDebugLog("[VM] sessions transition: inactive → active\n")
                    self.event = .agentsActive
                } else {
                    self.appendDebugLog("[VM] sessions transition: active → inactive\n")
                    self.event = .agentsIdle
                }
            }
            .store(in: &cancellables)

        state.$sessions
            .sink { [weak self] sessions in
                guard let self else { return }
                let currentIDs = Set(sessions.filter {
                    $0.status == .working || $0.status == .starting || $0.status == .waitingApproval
                }.map(\.id))
                let newIDs = currentIDs.subtracting(self.knownSessionIDs)
                self.knownSessionIDs = currentIDs
                if !newIDs.isEmpty && currentIDs.count > 1 {
                    self.appendDebugLog("[VM] new session joined: \(newIDs)\n")
                    self.event = .agentsActive
                }
            }
            .store(in: &cancellables)

        state.$sessions
            .sink { [weak self] sessions in
                guard let self else { return }
                let workingSessions = sessions.filter { $0.status == .working }
                var newMap: [String: String] = [:]
                var changedSession: AgentSession? = nil

                for session in workingSessions {
                    if let workingOn = session.workingOn {
                        newMap[session.id] = workingOn
                        if self.lastWorkingOnMap[session.id] != workingOn {
                            changedSession = session
                        }
                    }
                }

                self.lastWorkingOnMap = newMap

                if let session = changedSession {
                    self.appendDebugLog("[VM] toolActivityPeek: \(session.agentType.displayName) \(session.workingOn?.prefix(40) ?? "")\n")
                    self.event = .toolActivityPeek(session: session)
                }
            }
            .store(in: &cancellables)

        state.$completedSessions
            .removeDuplicates { $0.map(\.id) == $1.map(\.id) }
            .dropFirst()
            .sink { [weak self] sessions in
                guard let self, let latest = sessions.first else { return }
                self.notificationService.notifyTaskComplete(session: latest)
                self.event = .sessionCompleted(sessionId: latest.id)
            }
            .store(in: &cancellables)
    }


    private func setupHotkeys() {
        hotkeyManager.onToggle = { [weak self] in
            guard let self else { return }
            self.event = .toggleRequested
        }
        hotkeyManager.onQuickApprove = { [weak self] in
            guard let self else { return }
            if let approval = self.state.pendingApprovals.first {
                self.respondToApproval(requestId: approval.id, action: .allow)
            }
        }
        hotkeyManager.onJumpToTerminal = { [weak self] in
            guard let self else { return }
            if let session = self.state.activeSessions.first {
                _ = self.jumpToTerminal(for: session)
            }
        }
        hotkeyManager.onKillPrimary = { [weak self] in
            guard let self else { return }
            if let session = self.state.activeSessions.first {
                self.killSession(session)
            }
        }
        hotkeyManager.onDismissApprovals = { [weak self] in
            guard let self else { return }
            self.state.dismissAllApprovals()
        }
        hotkeyManager.start()
    }

    private func appendDebugLog(_ msg: String) {
        DebugLogWriter.shared.append(msg)
    }
}
