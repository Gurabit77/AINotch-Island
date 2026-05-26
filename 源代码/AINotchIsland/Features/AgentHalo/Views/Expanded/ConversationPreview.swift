import SwiftUI

struct ConversationPreview: View {
    let conversation: SessionConversation
    let workingOn: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let prompt = conversation.lastUserPrompt {
                userMessageBubble(prompt)
            }

            if let response = conversation.lastAssistantText {
                assistantMessageBubble(response)
            }

            if let tool = conversation.currentToolUse ?? workingOn {
                toolActivityRow(tool)
            }
        }
    }

    private func userMessageBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(L10n.app("agent.conversation.you", fallback: "You"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.blue.opacity(0.8))
                .frame(width: 20, alignment: .leading)

            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
    }

    private func assistantMessageBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 8))
                .foregroundStyle(.purple.opacity(0.6))
                .frame(width: 20, alignment: .leading)

            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func toolActivityRow(_ tool: String) -> some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.6)
            Text(tool)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.green.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
