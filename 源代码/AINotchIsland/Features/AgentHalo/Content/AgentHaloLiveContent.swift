import SwiftUI

struct AgentHaloLiveContent: NotchContentProtocol {
    let id = NotchContentRegistry.AgentHalo.active.id
    let agentHaloViewModel: AgentHaloViewModel
    let buddyEngine: CatAnimationEngine

    var priority: Int { NotchContentRegistry.AgentHalo.active.priority }
    var isExpandable: Bool { true }
    var expandsOnTap: Bool { true }
    var preventsAutoCollapse: Bool { agentHaloViewModel.state.pendingApprovals.first != nil }

    var strokeColor: Color {
        switch agentHaloViewModel.state.globalStatus {
        case .idle: return .white.opacity(0.2)
        case .working: return .green.opacity(0.3)
        case .waitingApproval: return .orange.opacity(0.4)
        case .error: return .red.opacity(0.4)
        }
    }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let hasActive = !agentHaloViewModel.state.activeSessions.isEmpty
        let extra: CGFloat = hasActive ? 80 : 40
        let height: CGFloat = hasActive ? baseHeight + 12 : baseHeight + 4
        return .init(width: baseWidth + extra, height: height)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: max(baseWidth + 420, 640), height: 560)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: baseRadius - 4, bottom: 20)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(AgentHaloCompactView(
            state: agentHaloViewModel.state,
            conversationMonitor: agentHaloViewModel.conversationMonitor,
            devServerMonitor: agentHaloViewModel.devServerMonitor,
            buddyEngine: buddyEngine
        ))
    }

    @MainActor
    func makeExpandedView() -> AnyView {
        AnyView(AgentHaloExpandedView(
            viewModel: agentHaloViewModel,
            conversationMonitor: agentHaloViewModel.conversationMonitor,
            gitStatusMonitor: agentHaloViewModel.gitStatusMonitor,
            devServerMonitor: agentHaloViewModel.devServerMonitor,
            buddyEngine: buddyEngine
        ))
    }
}
