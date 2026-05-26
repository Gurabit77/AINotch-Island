import SwiftUI
import Combine

enum AgentHaloDisplayMode: String, CaseIterable {
    case notch = "Notch"
    case pill = "Pill"
}

@MainActor
final class PillWindowController {
    static let shared = PillWindowController()

    private var pillWindow: OverlayPanelWindow?
    private var isVisible = false

    var displayMode: AgentHaloDisplayMode = .notch {
        didSet {
            if displayMode == .pill { showPill() }
            else { hidePill() }
        }
    }

    weak var agentHaloViewModel: AgentHaloViewModel?

    func showPill() {
        guard pillWindow == nil, let vm = agentHaloViewModel else { return }
        guard let screen = NSScreen.main else { return }

        let pillSize = CGSize(width: 280, height: 36)
        let x = screen.frame.midX - pillSize.width / 2
        let y = screen.frame.maxY - pillSize.height - 4

        let frame = NSRect(origin: CGPoint(x: x, y: y), size: pillSize)
        let window = OverlayPanelFactory.makePanel(
            frame: frame,
            level: OverlayWindowLevel.interactiveNotch
        )

        let hostingView = NSHostingView(rootView: PillView(viewModel: vm))
        window.contentView = hostingView
        window.orderFrontRegardless()
        pillWindow = window
        isVisible = true
    }

    func hidePill() {
        pillWindow?.orderOut(nil)
        pillWindow = nil
        isVisible = false
    }
}

struct PillView: View {
    @ObservedObject var viewModel: AgentHaloViewModel
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            compactPill
            if isExpanded {
                AgentHaloExpandedView(viewModel: viewModel, conversationMonitor: viewModel.conversationMonitor, gitStatusMonitor: viewModel.gitStatusMonitor, devServerMonitor: viewModel.devServerMonitor, buddyEngine: CatAnimationEngine())
                    .frame(width: 360, height: 400)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 16 : 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 16 : 18, style: .continuous))
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private var compactPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if viewModel.state.displayedActiveSessions.isEmpty {
                Text(L10n.app("agent.pill.noAgents", fallback: "No agents"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.app("agent.pill.activeCount", fallback: "%d active").replacingOccurrences(of: "%d", with: "\(viewModel.state.activeCount)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)

                if let primary = viewModel.state.displayedActiveSessions.first {
                    Text(primary.agentType.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !viewModel.state.pendingApprovals.isEmpty {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 36)
    }

    private var statusColor: Color {
        switch viewModel.state.globalStatus {
        case .working: return .green
        case .waitingApproval: return .orange
        case .error: return .red
        case .idle: return .gray
        }
    }
}
