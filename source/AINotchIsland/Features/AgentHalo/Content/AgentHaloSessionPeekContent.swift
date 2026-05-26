import SwiftUI

struct AgentHaloSessionPeekContent: NotchContentProtocol {
    let session: AgentSession
    let viewModel: AgentHaloViewModel
    let conversation: SessionConversation?

    var id: String { "agentHalo.peek" }
    var priority: Int { NotchContentRegistry.AgentHalo.active.priority + 2 }
    var strokeColor: Color { .green.opacity(0.3) }

    private var hasConversation: Bool {
        conversation?.lastUserPrompt != nil || conversation?.lastAssistantText != nil
    }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let width = max(baseWidth + 300, 420)
        let height: CGFloat = hasConversation ? 200 : baseHeight
        return .init(width: width, height: height)
    }

    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: baseRadius - 4, bottom: hasConversation ? 16 : baseRadius)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            SessionPeekView(
                session: session,
                viewModel: viewModel,
                conversation: conversation
            )
        )
    }
}

private struct SessionPeekView: View {
    let session: AgentSession
    let viewModel: AgentHaloViewModel
    let conversation: SessionConversation?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 14)
                .frame(height: 30)

            if let conversation, conversation.lastUserPrompt != nil || conversation.lastAssistantText != nil {
                Divider()
                    .background(Color.white.opacity(0.08))

                ConversationPreview(
                    conversation: conversation,
                    workingOn: session.workingOn
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.green.opacity(0.15))
        .contentShape(Rectangle())
        .onTapGesture {
            _ = viewModel.jumpToTerminal(for: session)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: session.agentType.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.green)

            Text(session.agentType.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            if let prompt = conversation?.lastUserPrompt {
                Text("·")
                    .foregroundStyle(.white.opacity(0.3))
                Text(prompt)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(session.agentType.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.cyan.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(.cyan.opacity(0.1))
                )

            Text(session.formattedDuration)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}
