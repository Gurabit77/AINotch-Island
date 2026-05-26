import SwiftUI
import Combine

@MainActor
final class AgentHaloState: ObservableObject {
    @Published var sessions: [AgentSession] = []
    @Published var pendingApprovals: [AgentApprovalRequest] = []
    @Published var globalStatus: AgentGlobalStatus = .idle
    @Published var runningAgents: Set<String> = []
    @Published var completedSessions: [AgentSession] = []

    private let maxHistory = 50
    private let persistence = SessionPersistence.shared
    private var idleCleanupTimer: Timer?

    func startIdleCleanupTimer() {
        idleCleanupTimer?.invalidate()
        idleCleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performIdleCleanup()
            }
        }
    }

    private func performIdleCleanup() {
        let timeout = TimeInterval(
            UserDefaults.standard.object(forKey: GeneralSettingsStorage.Keys.agentHaloIdleCleanupTimeout) as? Int ?? 7200
        )
        guard timeout > 0 else { return }
        let now = Date()
        for i in sessions.indices.reversed() {
            let session = sessions[i]
            guard session.status == .idle || (session.status == .working && !session.processDetected) else { continue }
            if now.timeIntervalSince(session.lastUpdated) > timeout {
                updateSession(id: session.id, status: .done)
            }
        }
    }

    func loadPersistedHistory() {
        let maxAge: TimeInterval = 7200
        let now = Date()
        completedSessions = persistence.loadAll().filter {
            now.timeIntervalSince($0.lastUpdated) <= maxAge
        }
    }

    var activeSessions: [AgentSession] {
        sessions.filter { $0.status != .done && ($0.status != .idle || $0.processDetected) }
    }

    var visibleSessions: [AgentSession] {
        sessions.filter { $0.status != .done && !SessionSilenceStore.shared.shouldSilence($0) }
    }

    /// Sessions that are BOTH active in the logical state-machine sense AND
    /// surface in the UI list (silence rules respected). This is the single
    /// number the UI should display so the "X active" badge always matches
    /// the number of cards a user can scroll to.
    var displayedActiveSessions: [AgentSession] {
        sessions.filter {
            $0.status != .done &&
            ($0.status != .idle || $0.processDetected) &&
            !SessionSilenceStore.shared.shouldSilence($0)
        }
    }

    var activeCount: Int {
        displayedActiveSessions.count
    }

    var allToolHistory: [ToolCallRecord] {
        sessions.flatMap { $0.toolHistory }.sorted { $0.timestamp > $1.timestamp }
    }

    func addSession(_ session: AgentSession) {
        // Exact-id match: this is the canonical update path.
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
            recalculateGlobalStatus()
            return
        }

        // Cross-source dedup tier 1 — pid match. When the bridge supplies a
        // pid in the hook payload (see bridge findAgentPID), and the scanner
        // has already recorded a session with the same pid, those two are
        // provably the same OS process. Merge unconditionally — pid is a
        // hard identity, not a heuristic.
        if let pid = session.pid {
            if let existingIdx = sessions.firstIndex(where: { existing in
                guard existing.id != session.id else { return false }
                guard existing.agentType == session.agentType else { return false }
                guard existing.status != .done else { return false }
                return existing.pid == pid
            }) {
                let winner = mergeSessions(existing: sessions[existingIdx], incoming: session)
                let losingId = (winner.id == sessions[existingIdx].id) ? session.id : sessions[existingIdx].id
                sessions[existingIdx] = winner
                sessions.removeAll { $0.id == losingId && $0.id != winner.id }
                recalculateGlobalStatus()
                return
            }
        }

        // Cross-source dedup tier 2 — (agentType, workingDirectory) match,
        // used only when no pid is available. Two safety rails keep us
        // from over-merging:
        //   1. cwd must be non-empty and not a generic root like $HOME or "/".
        //      A user's HOME is the default cwd for any unrelated agent,
        //      so matching on HOME would conflate independent sessions.
        //   2. there must be exactly ONE existing active session with that
        //      (agentType, cwd). If two are already in play, the incoming
        //      session represents a third independent instance — merging it
        //      into one of them would silently drop the other.
        if let cwd = session.terminalInfo?.workingDirectory,
           !cwd.isEmpty,
           !Self.isAmbiguousWorkingDirectory(cwd) {
            let candidates = sessions.indices.filter { idx in
                let existing = sessions[idx]
                guard existing.id != session.id else { return false }
                guard existing.agentType == session.agentType else { return false }
                guard existing.status != .done else { return false }
                guard existing.terminalInfo?.workingDirectory == cwd else { return false }
                return true
            }
            if candidates.count == 1 {
                let existingIdx = candidates[0]
                let winner = mergeSessions(existing: sessions[existingIdx], incoming: session)
                let losingId = (winner.id == sessions[existingIdx].id) ? session.id : sessions[existingIdx].id
                sessions[existingIdx] = winner
                sessions.removeAll { $0.id == losingId && $0.id != winner.id }
                recalculateGlobalStatus()
                return
            }
            // candidates.count == 0 → no match, fall through and append.
            // candidates.count > 1  → ambiguous, fall through and append
            //                          (correct: keep all three visible).
        }

        sessions.append(session)
        recalculateGlobalStatus()
    }

    /// Returns true if the cwd is too generic to be a reliable identity
    /// signal — $HOME, "/", an empty string, or "/tmp" are all paths that
    /// totally unrelated agents commonly share, so they must not trigger
    /// a merge.
    private static func isAmbiguousWorkingDirectory(_ cwd: String) -> Bool {
        let normalized = cwd.hasSuffix("/") && cwd.count > 1 ? String(cwd.dropLast()) : cwd
        if normalized.isEmpty { return true }
        if normalized == "/" { return true }
        if normalized == "/tmp" { return true }
        if normalized == NSHomeDirectory() { return true }
        return false
    }

    /// When two sessions describe the same real agent (matched by
    /// agentType + cwd), pick the more authoritative one and absorb the
    /// other's metadata. Connection-type priority: hooked > transcript >
    /// scanned. Hooked owns the protocol so its sessionId becomes canonical.
    private func mergeSessions(existing: AgentSession, incoming: AgentSession) -> AgentSession {
        let priority: (AgentConnectionType) -> Int = {
            switch $0 {
            case .hooked: return 3
            case .transcript: return 2
            case .detected: return 1
            case .scanned: return 0
            }
        }
        let preferIncoming = priority(incoming.connectionType) > priority(existing.connectionType)
        var winner = preferIncoming ? incoming : existing
        let loser = preferIncoming ? existing : incoming

        // Absorb loser's enrichment data that the winner might be missing.
        if winner.pid == nil { winner.pid = loser.pid }
        if winner.processDetected == false && loser.processDetected { winner.processDetected = true }
        if winner.lastProcessSeen == nil { winner.lastProcessSeen = loser.lastProcessSeen }
        if winner.terminalInfo?.workingDirectory == nil { winner.terminalInfo?.workingDirectory = loser.terminalInfo?.workingDirectory }
        if winner.terminalInfo?.terminalApp.isEmpty ?? true {
            if let app = loser.terminalInfo?.terminalApp, !app.isEmpty {
                winner.terminalInfo?.terminalApp = app
            }
        }
        if winner.toolHistory.isEmpty { winner.toolHistory = loser.toolHistory }
        if winner.tokenUsage == nil { winner.tokenUsage = loser.tokenUsage }
        if winner.workingOn == nil { winner.workingOn = loser.workingOn }
        winner.lastUpdated = Date()
        return winner
    }

    func updateSession(id: String, status: AgentSessionStatus) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        let oldStatus = sessions[idx].status
        sessions[idx].status = status
        sessions[idx].lastUpdated = Date()

        if status == .done && oldStatus != .done {
            archiveSession(sessions[idx])
        }

        recalculateGlobalStatus()
    }

    func updateSessionWorkingOn(id: String, workingOn: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].workingOn = workingOn
        sessions[idx].lastUpdated = Date()
    }

    func touchSession(id: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].lastUpdated = Date()
    }

    func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
        recalculateGlobalStatus()
    }

    func addApproval(_ approval: AgentApprovalRequest) {
        pendingApprovals.append(approval)
        if let idx = sessions.firstIndex(where: { $0.id == approval.sessionId }) {
            sessions[idx].status = .waitingApproval
            sessions[idx].currentApproval = approval
        }
        recalculateGlobalStatus()
    }

    func resolveApproval(id: String, response: AgentApprovalResponse) {
        pendingApprovals.removeAll { $0.id == id }
        for idx in sessions.indices {
            if sessions[idx].currentApproval?.id == id {
                sessions[idx].status = .working
                sessions[idx].currentApproval = nil
            }
        }
        recalculateGlobalStatus()
    }

    func dismissAllApprovals() {
        let sessionIds = pendingApprovals.map { $0.sessionId }
        pendingApprovals.removeAll()
        for idx in sessions.indices where sessionIds.contains(sessions[idx].id) {
            if sessions[idx].status == .waitingApproval {
                sessions[idx].status = .working
                sessions[idx].currentApproval = nil
            }
        }
        recalculateGlobalStatus()
    }

    func cleanupExpiredApprovals() {
        let timeout: TimeInterval = 120
        let now = Date()
        let expired = pendingApprovals.filter { now.timeIntervalSince($0.createdAt) > timeout }
        guard !expired.isEmpty else { return }

        let expiredIds = Set(expired.map { $0.id })
        pendingApprovals.removeAll { expiredIds.contains($0.id) }

        for idx in sessions.indices where sessions[idx].status == .waitingApproval {
            if let approval = sessions[idx].currentApproval, expiredIds.contains(approval.id) {
                sessions[idx].status = .working
                sessions[idx].currentApproval = nil
            }
        }
        recalculateGlobalStatus()
    }

    func recalculateGlobalStatus() {
        if sessions.contains(where: { $0.status == .error }) {
            globalStatus = .error
        } else if sessions.contains(where: { $0.status == .waitingApproval }) {
            globalStatus = .waitingApproval
        } else if sessions.contains(where: { $0.status == .working || $0.status == .starting }) {
            globalStatus = .working
        } else if sessions.contains(where: { $0.processDetected && $0.status != .done }) {
            globalStatus = .working
        } else {
            globalStatus = .idle
        }
    }

    private func archiveSession(_ session: AgentSession) {
        let maxAge: TimeInterval = 7200
        let now = Date()
        completedSessions.removeAll { now.timeIntervalSince($0.lastUpdated) > maxAge }
        completedSessions.insert(session, at: 0)
        if completedSessions.count > maxHistory {
            completedSessions.removeLast()
        }
        persistence.save(session)
    }
}

enum AgentGlobalStatus: Equatable {
    case idle, working, waitingApproval, error
}
