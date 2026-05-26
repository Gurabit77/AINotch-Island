import SwiftUI

@MainActor
final class NotchAgentHaloEventsHandler {
    private let notchViewModel: NotchViewModel
    private let agentHaloViewModel: AgentHaloViewModel
    private let buddyEngine: CatAnimationEngine
    private var lastExpandTime: Date = .distantPast
    private var autoCollapseTask: Task<Void, Never>?
    private var expandTask: Task<Void, Never>?

    init(
        notchViewModel: NotchViewModel,
        agentHaloViewModel: AgentHaloViewModel,
        buddyEngine: CatAnimationEngine
    ) {
        self.notchViewModel = notchViewModel
        self.agentHaloViewModel = agentHaloViewModel
        self.buddyEngine = buddyEngine
    }

    func handleAgentHalo(_ event: AgentHaloEvent) {
        switch event {
        case .agentsActive:
            ensureLiveContentVisible()
            buddyEngine.showTemporaryScene(.waving, duration: 2.0)

        case .agentsIdle:
            buddyEngine.showTemporaryScene(.idleSitDown, duration: 2.0)
            refreshLiveContent()

        case .approvalRequested(let requestId):
            SoundManager.shared.play(.approvalNeeded)
            buddyEngine.showTemporaryScene(.idlePeek, duration: 2.0)
            ensureLiveContentVisible()
            showApprovalMedium(requestId: requestId)

        case .approvalResolved(_):
            buddyEngine.showTemporaryScene(.happy, duration: 1.5)
            if agentHaloViewModel.state.pendingApprovals.isEmpty {
                notchViewModel.hideTemporaryNotification()
                refreshLiveContent()
                scheduleAutoCollapse(delay: 1.5)
            } else if let next = agentHaloViewModel.state.pendingApprovals.first {
                showApprovalMedium(requestId: next.id)
            }

        case .statusChanged(let status):
            switch status {
            case .working:
                buddyEngine.showTemporaryScene(.idleCurious, duration: 1.0)
            case .error:
                buddyEngine.showTemporaryScene(.surprised, duration: 2.5)
            case .waitingApproval:
                buddyEngine.showTemporaryScene(.confused, duration: 1.5)
            case .idle:
                break
            }
            refreshLiveContent()

        case .toggleRequested:
            ensureLiveContentVisible()
            expandWithRetry(cancelCollapse: true)

        case .sessionCompleted(let sessionId):
            // No pop-up notification on completion. The triggering source
            // (Stop / SessionEnd) fires once per assistant turn for Claude /
            // mimo / codex / etc — so any temporary banner here would flash
            // on every CLI exchange. The Compact island view already shows
            // current activity, recent tools, and a celebration buddy
            // animation; the full conversation is one tap away in the
            // expanded panel.
            if let session = agentHaloViewModel.state.completedSessions.first(where: { $0.id == sessionId }) {
                if session.duration > 20 * 60 {
                    buddyEngine.showTemporaryScene(.tired, duration: 3.0)
                } else {
                    buddyEngine.showTemporaryScene(.celebrating, duration: 2.5)
                }
            }
            refreshLiveContent()

        case .terminalJumpFailed(let message):
            buddyEngine.showTemporaryScene(.confused, duration: 2.0)
            notchViewModel.send(
                .showTemporaryNotification(
                    AgentHaloToastContent(message: message),
                    duration: 3.0
                )
            )

        case .toolActivityPeek(let session):
            if let lastTool = session.toolHistory.last {
                reactToTool(lastTool.tool)
            }
            refreshLiveContent()
        }
    }

    private func reactToTool(_ tool: String) {
        switch tool {
        case let t where t.contains("Bash"):
            buddyEngine.showTemporaryScene(.idlePeek, duration: 1.0)
        case let t where t.contains("Web"):
            buddyEngine.showTemporaryScene(.downloading, duration: 1.0)
        case let t where t.contains("Agent"):
            buddyEngine.showTemporaryScene(.idleCurious, duration: 1.0)
        case let t where t.contains("Edit") || t.contains("Write"):
            buddyEngine.showTemporaryScene(.coding, duration: 0.8)
        default:
            break
        }
    }

    // MARK: - Approval Notification

    private func showApprovalMedium(requestId: String) {
        guard let approval = agentHaloViewModel.state.pendingApprovals
            .first(where: { $0.id == requestId }) else { return }

        let content = AgentHaloApprovalMediumContent(
            approval: approval,
            agentHaloViewModel: agentHaloViewModel
        )
        notchViewModel.send(.showTemporaryNotification(content, duration: .infinity))
    }

    private func showApprovalNotification(requestId: String) {
        guard let approval = agentHaloViewModel.state.pendingApprovals
            .first(where: { $0.id == requestId }) else { return }

        let content = AgentHaloApprovalContent(
            approval: approval,
            agentHaloViewModel: agentHaloViewModel
        )
        notchViewModel.send(.showTemporaryNotification(content, duration: .infinity))
    }

    // MARK: - Private Helpers

    private func refreshLiveContent() {
        notchViewModel.send(
            .showLiveActivity(
                AgentHaloLiveContent(agentHaloViewModel: agentHaloViewModel, buddyEngine: buddyEngine)
            )
        )
    }

    private func ensureLiveContentVisible() {
        if notchViewModel.canRestoreDismissedContent {
            notchViewModel.restoreDismissedContent()
        }
        refreshLiveContent()
    }

    private func expandWithRetry(
        cancelCollapse: Bool = false,
        initialDelay: TimeInterval = 0.2,
        onSuccess: (() -> Void)? = nil
    ) {
        expandTask?.cancel()
        if cancelCollapse { autoCollapseTask?.cancel() }

        expandTask = Task { @MainActor [weak self, weak notchViewModel] in
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            guard let self, let notchViewModel, !Task.isCancelled else { return }

            var attempts = 0
            for _ in 0..<30 {
                guard !Task.isCancelled else { return }

                if notchViewModel.notchModel.temporaryNotificationContent != nil {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }

                if notchViewModel.canExpandActiveLiveActivity {
                    notchViewModel.expandActiveLiveActivity()
                    self.lastExpandTime = Date()
                    onSuccess?()
                    return
                }

                attempts += 1
                if attempts >= 8 { break }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    private func scheduleAutoCollapse(delay: TimeInterval) {
        autoCollapseTask?.cancel()
        autoCollapseTask = Task { @MainActor [weak self, weak notchViewModel] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, let notchViewModel, !Task.isCancelled else { return }
            guard self.agentHaloViewModel.state.pendingApprovals.isEmpty else { return }
            guard !notchViewModel.notchModel.isLiveActivityExpanded ||
                  notchViewModel.notchModel.liveActivityContent?.preventsAutoCollapse != true else { return }
            notchViewModel.handleOutsideClick()
        }
    }

    private nonisolated func appendDebugLog(_ msg: String) {
        DebugLogWriter.shared.append("\(msg)\n")
    }
}
