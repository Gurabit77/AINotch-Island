import SwiftUI

struct InlineApprovalBar: View {
    let approval: AgentApprovalRequest
    let viewModel: AgentHaloViewModel
    @Environment(\.notchScale) var scale

    var body: some View {
        HStack(spacing: 6.scaled(by: scale)) {
            Circle()
                .fill(.orange)
                .frame(width: 5, height: 5)

            Text(commandText)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: 120)

            Spacer(minLength: 4)

            if approval.type == .askUserQuestionInfo {
                // AskUserQuestion can't be answered from the island — Claude
                // is asking via terminal plain text. Tell the user that.
                HStack(spacing: 3) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 8, weight: .bold))
                    Text(L10n.app("agent.approval.terminalShort", fallback: "终端回答"))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.blue.opacity(0.15)))
            } else if approval.type == .question {
                // AskUserQuestion / ExitPlanMode carry user-defined options,
                // so the fixed Allow / Deny / Always trio is meaningless
                // here. Surface a hint that the choices live in the
                // expanded view instead.
                HStack(spacing: 3) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8, weight: .bold))
                    Text(L10n.app("agent.approval.viewOptions", fallback: "选项"))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.blue.opacity(0.15)))
            } else {
                Button {
                    viewModel.respondToApproval(requestId: approval.id, action: .allow)
                } label: {
                    HStack(spacing: 2) {
                        Text("⌘Y")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        Text(L10n.app("agent.approval.allow", fallback: "Allow"))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.green.opacity(0.15)))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.respondToApproval(requestId: approval.id, action: .deny)
                } label: {
                    HStack(spacing: 2) {
                        Text("⌘N")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        Text(L10n.app("agent.approval.deny", fallback: "Deny"))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.red.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.respondToApproval(requestId: approval.id, action: .alwaysAllow)
                } label: {
                    Text(L10n.app("agent.approval.always", fallback: "Always"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var commandText: String {
        if approval.type == .question {
            return approval.title
        }
        if let cmd = approval.bashCommand {
            return String(cmd.prefix(40))
        }
        return approval.toolName ?? L10n.app("agent.approval.action", fallback: "Action")
    }
}
