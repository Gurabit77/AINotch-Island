import SwiftUI

struct AgentHaloToastContent: NotchContentProtocol {
    let message: String

    var id: String { "agentHalo.toast" }
    var priority: Int { NotchContentRegistry.AgentHalo.approval.priority + 10 }

    var strokeColor: Color { .orange.opacity(0.3) }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 80, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
        )
    }
}
