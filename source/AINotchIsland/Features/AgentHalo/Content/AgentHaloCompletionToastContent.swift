import SwiftUI

struct AgentHaloCompletionToastContent: NotchContentProtocol {
    let id = "agentHalo.completionToast"
    let session: AgentSession
    let viewModel: AgentHaloViewModel

    var priority: Int { NotchContentRegistry.AgentHalo.active.priority + 5 }
    var isExpandable: Bool { false }
    var strokeColor: Color { .green.opacity(0.4) }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 160, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            CompletionToastView(session: session, viewModel: viewModel)
        )
    }
}

private struct CompletionToastView: View {
    let session: AgentSession
    let viewModel: AgentHaloViewModel
    @State private var checkmarkTrim: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.green.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                CheckmarkShape()
                    .trim(from: 0, to: checkmarkTrim)
                    .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 10)
            }

            Text(session.agentType.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text("·")
                .foregroundStyle(.white.opacity(0.3))

            Text(L10n.app("agent.toast.done", fallback: "Done — tap to jump"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.green.opacity(0.8))

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            _ = viewModel.jumpToTerminal(for: session)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                checkmarkTrim = 1
            }
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.8))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.2))
        return path
    }
}
