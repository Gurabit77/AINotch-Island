import SwiftUI

struct AgentHaloApprovalContent: NotchContentProtocol {
    let approval: AgentApprovalRequest
    let agentHaloViewModel: AgentHaloViewModel

    var id: String { "agentHalo.approval.\(approval.id)" }
    var priority: Int { NotchContentRegistry.AgentHalo.approval.priority }

    var strokeColor: Color {
        switch approval.riskLevel {
        case .low: return .green.opacity(0.3)
        case .medium: return .orange.opacity(0.4)
        case .high: return .red.opacity(0.4)
        }
    }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 140, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            AgentHaloApprovalCompactView(
                approval: approval,
                onApprove: { [weak agentHaloViewModel] in
                    agentHaloViewModel?.respondToApproval(requestId: approval.id, action: .allow)
                },
                onDeny: { [weak agentHaloViewModel] in
                    agentHaloViewModel?.respondToApproval(requestId: approval.id, action: .deny)
                }
            )
        )
    }

    @MainActor
    func handleTap(at point: CGPoint, in bounds: CGSize) -> Bool {
        guard approval.type != .question else { return false }

        let buttonsWidth: CGFloat = 48
        let rightPadding: CGFloat = 14
        let buttonsStartX = bounds.width - rightPadding - buttonsWidth

        guard point.x >= buttonsStartX else { return false }

        let midX = buttonsStartX + buttonsWidth / 2
        if point.x < midX {
            agentHaloViewModel.respondToApproval(requestId: approval.id, action: .deny)
        } else {
            agentHaloViewModel.respondToApproval(requestId: approval.id, action: .allow)
        }
        return true
    }
}

