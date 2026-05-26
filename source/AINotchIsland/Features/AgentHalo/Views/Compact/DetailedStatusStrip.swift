import SwiftUI
import Combine

struct DetailedStatusStrip: View {
    @ObservedObject var state: AgentHaloState
    @State private var durationTick = false

    private let durationTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if let primary = state.activeSessions.first {
            HStack(spacing: 6) {
                Text(primary.agentType.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text("\u{00B7}")
                    .foregroundStyle(.white.opacity(0.3))

                Text(primary.workingOn ?? L10n.app("agent.status.idle", fallback: "Idle"))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                Spacer(minLength: 4)

                let _ = durationTick
                Text(primary.formattedDuration)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
            .onReceive(durationTimer) { _ in durationTick.toggle() }
        }
    }
}
