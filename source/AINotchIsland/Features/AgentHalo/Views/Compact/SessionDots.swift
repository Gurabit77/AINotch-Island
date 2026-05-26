import SwiftUI

struct SessionDots: View {
    let sessions: [AgentSession]
    let primaryIndex: Int

    private let maxVisibleDots = 5
    private let dotSize: CGFloat = 5
    private let primaryDotSize: CGFloat = 7
    private let spacing: CGFloat = 3

    var body: some View {
        HStack(spacing: spacing) {
            let visible = Array(sessions.prefix(maxVisibleDots))
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, session in
                Circle()
                    .fill(dotColor(for: session.status))
                    .frame(
                        width: index == primaryIndex ? primaryDotSize : dotSize,
                        height: index == primaryIndex ? primaryDotSize : dotSize
                    )
                    .shadow(color: dotColor(for: session.status).opacity(0.5), radius: index == primaryIndex ? 3 : 0)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sessions.count)
            }

            if sessions.count > maxVisibleDots {
                Text("+\(sessions.count - maxVisibleDots)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessions.map(\.id))
    }

    private func dotColor(for status: AgentSessionStatus) -> Color {
        switch status {
        case .working, .starting:
            return .green
        case .waitingApproval:
            return .orange
        case .error:
            return .red
        case .idle:
            return .gray
        case .done, .completing:
            return .green.opacity(0.5)
        case .interrupted:
            return .yellow
        }
    }
}
