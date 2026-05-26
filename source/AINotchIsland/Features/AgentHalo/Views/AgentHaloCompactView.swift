import SwiftUI

private struct ToolGroup: Identifiable {
    let id: String
    let tool: String
    let count: Int
}

struct AgentHaloCompactView: View {
    @ObservedObject var state: AgentHaloState
    @ObservedObject var conversationMonitor: ConversationMonitor
    @ObservedObject var devServerMonitor: DevServerMonitor
    // The buddy engine is owned by NotchEventCoordinator and shared with
    // NotchAgentHaloEventsHandler + AgentHaloExpandedView. The CompactView
    // MUST observe the same instance — otherwise scene triggers fired by
    // the event handler (showTemporaryScene/showOverlay) update a different
    // engine and never reach the pixel cat the user is looking at.
    @ObservedObject var buddyEngine: CatAnimationEngine
    @Environment(\.notchScale) var scale

    var body: some View {
        HStack(spacing: 6) {
            buddyView

            if !state.activeSessions.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    infoRow
                    toolActivityTicker
                }

                Spacer(minLength: 2)

                HStack(spacing: 5) {
                    if !state.pendingApprovals.isEmpty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 5, height: 5)
                    }
                    Text("\(state.displayedActiveSessions.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 10.scaled(by: scale))
        .onAppear { buddyEngine.start() }
        .onDisappear { buddyEngine.stop() }
        .onChange(of: state.pendingApprovals.count) { old, new in
            if new > old {
                buddyEngine.showOverlay(.approvalNeeded)
                if state.pendingApprovals.last?.riskLevel == .high {
                    buddyEngine.showTemporaryScene(.nervous, duration: 2.0)
                } else {
                    buddyEngine.showTemporaryScene(.idlePeek, duration: 1.5)
                }
            }
        }
        .onChange(of: state.globalStatus) { oldStatus, newStatus in
            if newStatus == .error {
                buddyEngine.showOverlay(.errorOccurred)
                buddyEngine.showTemporaryScene(.surprised, duration: 2.5)
            } else if oldStatus == .error && newStatus == .working {
                buddyEngine.showTemporaryScene(.happy, duration: 1.5)
            } else if oldStatus == .idle && newStatus == .working {
                buddyEngine.showTemporaryScene(.waving, duration: 2.0)
            }
            updateScene()
        }
        .onChange(of: completedToolCount) { old, new in
            if new > old {
                buddyEngine.showOverlay(.toolDone)
                let toolCount = new - old
                if toolCount >= 3 {
                    buddyEngine.showTemporaryScene(.idleDance, duration: 1.0)
                }
            }
            updateScene()
        }
        .onChange(of: state.completedSessions.count) { old, new in
            if new > old {
                buddyEngine.showOverlay(.sessionComplete)
                let longestDuration = state.completedSessions.last?.duration ?? 0
                if longestDuration > 30 * 60 {
                    buddyEngine.showTemporaryScene(.tired, duration: 3.0)
                } else if longestDuration > 10 * 60 {
                    buddyEngine.showTemporaryScene(.morningStretch, duration: 2.5)
                } else {
                    buddyEngine.showTemporaryScene(.celebrating, duration: 2.5)
                }
            }
            updateScene()
        }
        .onChange(of: state.activeSessions.count) { old, new in
            if new > old && new >= 3 {
                buddyEngine.showTemporaryScene(.idleCurious, duration: 1.5)
            }
            updateScene()
        }
        .onChange(of: buddyEngine.idleTickCount) { _, count in
            if count > 0 && count % 10 == 0 {
                updateScene()
            }
        }
    }

    // MARK: - Scene Computation

    private func updateScene() {
        buddyEngine.updateScene(computeScene())
    }

    private func computeScene() -> CrabScene {
        // High priority: approval states
        if state.pendingApprovals.contains(where: { $0.riskLevel == .high }) {
            return .nervous
        }
        if state.globalStatus == .waitingApproval {
            return state.pendingApprovals.count > 1 ? .nervous : .confused
        }

        // Error state
        if state.globalStatus == .error {
            return .surprised
        }

        // Working states - rich tool-based mapping
        if state.globalStatus == .working {
            let currentTool = latestActiveTool
            let sessionCount = state.activeSessions.count
            let maxDuration = state.activeSessions.map(\.duration).max() ?? 0
            let totalTools = state.activeSessions.reduce(0) { $0 + $1.toolHistory.count }

            // Multi-agent parallel work
            if sessionCount >= 4 {
                return .idleDance
            }
            if sessionCount >= 2 {
                return .idleCurious
            }

            // Tool-specific scenes
            if let tool = currentTool {
                switch tool {
                // Reading/searching - crab is browsing
                case let t where t.contains("Read"):
                    return .reading
                case let t where t.contains("Grep") || t.contains("Glob") || t.contains("Search"):
                    return .idleLookLeft
                case let t where t.contains("LSP"):
                    return .idleLookRight

                // Writing/editing - crab is coding intensely
                case let t where t.contains("Edit"):
                    return .coding
                case let t where t.contains("Write"):
                    return totalTools > 10 ? .idleChaseButterfly : .coding
                case let t where t.contains("NotebookEdit"):
                    return .coding

                // Bash/terminal - crab watches nervously or excitedly
                case let t where t.contains("Bash"):
                    if let approval = state.pendingApprovals.first, approval.riskLevel == .medium {
                        return .nervous
                    }
                    return maxDuration > 5 * 60 ? .watching : .idlePeek

                // Web/network
                case let t where t.contains("WebFetch") || t.contains("WebSearch"):
                    return .downloading

                // Agent spawning
                case let t where t.contains("Agent"):
                    return .idleCurious

                // Planning/thinking
                case let t where t.contains("Plan") || t.contains("Todo") || t.contains("Task"):
                    return .thinking

                default:
                    return .coding
                }
            }

            // No active tool but working - thinking/waiting for response
            if maxDuration > 20 * 60 {
                return .music
            }
            if maxDuration > 10 * 60 {
                return .nightOwl
            }
            if !devServerMonitor.servers.isEmpty {
                return .watching
            }

            return .thinking
        }

        // Idle states - progressive relaxation
        let idleTicks = buddyEngine.idleTickCount
        if idleTicks > 600 {
            return .sleeping
        }
        if idleTicks > 360 {
            return .idleDoze
        }
        if idleTicks > 180 {
            return .idleSitDown
        }

        // Recent completion afterglow
        if let completed = state.completedSessions.last,
           completed.status == .done {
            let elapsed = Date().timeIntervalSince(completed.lastUpdated)
            if elapsed < 30 {
                return .celebrating
            }
            if elapsed < 120 {
                return .sunglasses
            }
            if elapsed < 300 {
                return .happy
            }
        }

        return .idle
    }

    private var latestActiveTool: String? {
        for session in state.activeSessions {
            if let conv = conversationMonitor.conversations[session.id],
               let tool = conv.currentToolUse, !tool.isEmpty {
                return tool
            }
        }
        for session in state.activeSessions {
            if let last = session.toolHistory.last, last.status != .completed {
                return last.tool
            }
        }
        return nil
    }

    // MARK: - Layout

    private var infoRow: some View {
        HStack(spacing: 4) {
            activeDots

            if let activity = currentActivity {
                Text(activity)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var toolActivityTicker: some View {
        let groups = groupedRecentTools
        return HStack(spacing: 4) {
            ForEach(groups) { group in
                toolGroupPill(group)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: groups.map(\.id))
    }

    private func toolGroupPill(_ group: ToolGroup) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
            Text(group.tool)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            if group.count > 1 {
                Text("×\(group.count)")
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Buddy

    private var buddyView: some View {
        let mood = CatMood.from(status: state.globalStatus)
        return PixelCatView(mood: mood, engine: buddyEngine)
            .scaleEffect(0.75)
    }

    // MARK: - Data

    private var currentActivity: String? {
        for session in state.activeSessions where session.connectionType == .hooked {
            if let workingOn = session.workingOn, !workingOn.isEmpty {
                return workingOn
            }
        }
        for session in state.activeSessions {
            if let workingOn = session.workingOn, !workingOn.isEmpty {
                return workingOn
            }
        }
        return nil
    }

    private var groupedRecentTools: [ToolGroup] {
        let tools = recentTools
        var groups: [ToolGroup] = []
        for record in tools {
            if let last = groups.last, last.tool == record.tool {
                groups[groups.count - 1] = ToolGroup(
                    id: last.id, tool: last.tool, count: last.count + 1
                )
            } else {
                groups.append(ToolGroup(
                    id: record.id.uuidString, tool: record.tool, count: 1
                ))
            }
        }
        return Array(groups.suffix(4))
    }

    private var recentTools: [ToolCallRecord] {
        let hookedHistory = state.activeSessions
            .filter { $0.connectionType == .hooked }
            .flatMap { $0.toolHistory }
            .filter { $0.status == .completed }
        if !hookedHistory.isEmpty {
            return Array(hookedHistory.suffix(8))
        }
        let scannedHistory = state.activeSessions
            .filter { $0.connectionType == .scanned }
            .flatMap { $0.toolHistory }
            .filter { $0.status == .completed }
            .filter { record in
                guard record.tool == "Process" else { return true }
                let noise = ["screencapture", "mdworker", "mds", "kernel", "launchd", "WindowServer", "syslogd", "sourcekit-lsp"]
                if let cmd = record.command {
                    return !noise.contains(where: { cmd.contains($0) })
                }
                return true
            }
        return Array(scannedHistory.suffix(8))
    }

    private var completedToolCount: Int {
        state.activeSessions
            .flatMap { $0.toolHistory }
            .filter { $0.status == .completed }
            .count
    }

    @State private var breathePhase = false

    private var activeDots: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(state.activeSessions.prefix(3).enumerated()), id: \.element.id) { idx, session in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(sessionDotColor(session.status))
                    .frame(width: 2.5, height: dotHeight(for: session))
                    .opacity(session.status == .working ? (breathePhase ? 1.0 : 0.4) : 1.0)
                    .animation(
                        session.status == .working
                            ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(Double(idx) * 0.2)
                            : .default,
                        value: breathePhase
                    )
            }
        }
        .onAppear { breathePhase = true }
    }

    private func dotHeight(for session: AgentSession) -> CGFloat {
        switch session.status {
        case .working:
            let hash = abs(session.id.hashValue)
            return CGFloat(5 + (hash % 4))
        case .waitingApproval: return 8
        default: return 5
        }
    }

    private func sessionDotColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .starting: return .cyan
        case .working: return .green
        case .waitingApproval: return .orange
        case .completing: return .cyan
        case .done: return .gray
        case .error: return .red
        case .interrupted: return .yellow
        }
    }
}
