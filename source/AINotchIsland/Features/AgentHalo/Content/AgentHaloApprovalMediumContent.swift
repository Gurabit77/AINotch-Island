import SwiftUI

struct AgentHaloApprovalMediumContent: NotchContentProtocol {
    let approval: AgentApprovalRequest
    let agentHaloViewModel: AgentHaloViewModel

    var id: String { "agentHalo.approvalMedium.\(approval.id)" }
    var priority: Int { NotchContentRegistry.AgentHalo.approval.priority }
    var isExpandable: Bool { false }

    var strokeColor: Color {
        switch approval.riskLevel {
        case .low: return .green.opacity(0.3)
        case .medium: return .orange.opacity(0.4)
        case .high: return .red.opacity(0.4)
        }
    }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let optionCount = approval.question?.options.count ?? 0
        let contentHeight: CGFloat
        if optionCount > 0 {
            contentHeight = 50 + CGFloat(optionCount) * 34 + 30
        } else if approval.diff != nil {
            contentHeight = 120
        } else {
            contentHeight = 80
        }
        return .init(width: baseWidth + 220, height: baseHeight + contentHeight)
    }

    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: baseRadius, bottom: baseRadius + 6)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            ApprovalMediumView(approval: approval, viewModel: agentHaloViewModel)
        )
    }

    @MainActor
    func handleTap(at point: CGPoint, in bounds: CGSize) -> Bool {
        false
    }
}

private struct ApprovalMediumView: View {
    let approval: AgentApprovalRequest
    let viewModel: AgentHaloViewModel
    @State private var selectedOptions: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(riskColor)
                .frame(width: 6, height: 6)

            if approval.type == .askUserQuestionInfo {
                Text(L10n.app("agent.approval.terminalQuestion", fallback: "Claude 在问你（请到终端回答）"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            } else if approval.type == .question {
                Text(L10n.app("agent.approval.choiceNeeded", fallback: "需要你的选择"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(approval.toolName ?? L10n.app("agent.approval.permissionRequest", fallback: "权限请求"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            Text(typeBadge)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    private var content: some View {
        if let question = approval.question {
            questionView(question)
        } else if let command = approval.bashCommand {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.app("agent.approval.executeCommand", fallback: "执行命令"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(command)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            }
        } else {
            Text(approval.description.isEmpty ? approval.title : approval.description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private func questionView(_ question: AgentQuestionContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)

            VStack(spacing: 4) {
                ForEach(question.options) { option in
                    optionButton(option, isMulti: question.isMultiSelect)
                }
            }
        }
    }

    private func optionButton(_ option: AgentQuestionOption, isMulti: Bool) -> some View {
        let isSelected = selectedOptions.contains(option.id)
        let isReadOnly = approval.type == .askUserQuestionInfo
        return Button {
            // Read-only info card: clicking should do nothing. Claude was
            // told to ask via plain text; the answer needs to come back
            // through the terminal, not through the island.
            guard !isReadOnly else { return }
            DebugLogWriter.shared.append("[ApprovalMedium] option tapped: id=\(option.id) label=\(option.label) wasSelected=\(isSelected) isMulti=\(isMulti)\n")
            if isMulti {
                if isSelected { selectedOptions.remove(option.id) }
                else { selectedOptions.insert(option.id) }
            } else {
                selectedOptions = [option.id]
            }
            DebugLogWriter.shared.append("[ApprovalMedium] selectedOptions now: \(selectedOptions)\n")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isReadOnly
                    ? "circle.dotted"
                    : (isSelected
                        ? (isMulti ? "checkmark.square.fill" : "largecircle.fill.circle")
                        : (isMulti ? "square" : "circle"))
                )
                .font(.system(size: 11))
                .foregroundStyle(isReadOnly ? Color.secondary : (isSelected ? Color.blue : Color.secondary))

                Text(option.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)

                if let desc = option.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected && !isReadOnly ? Color.blue.opacity(0.15) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isReadOnly)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            Spacer()
            if approval.type == .askUserQuestionInfo {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10, weight: .medium))
                    Text(L10n.app("agent.approval.replyInTerminal", fallback: "请在终端回复"))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.blue.opacity(0.15)))
            } else if approval.type == .question {
                actionButton(L10n.app("agent.approval.submit", fallback: "提交"), icon: "paperplane.fill", color: .blue) {
                    DebugLogWriter.shared.append("[ApprovalMedium] submit clicked: requestId=\(approval.id) selectedOptions=\(Array(selectedOptions))\n")
                    viewModel.respondToApproval(
                        requestId: approval.id,
                        action: .answer(selectedOptions: Array(selectedOptions))
                    )
                }
                .disabled(selectedOptions.isEmpty)
                .opacity(selectedOptions.isEmpty ? 0.5 : 1)
            } else {
                actionButton(L10n.app("agent.approval.deny", fallback: "拒绝"), icon: "xmark", color: .red) {
                    viewModel.respondToApproval(requestId: approval.id, action: .deny)
                }
                actionButton(L10n.app("agent.approval.allow", fallback: "允许"), icon: "checkmark", color: .green) {
                    viewModel.respondToApproval(requestId: approval.id, action: .allow)
                }
                actionButton(L10n.app("agent.approval.alwaysAllow", fallback: "始终允许"), icon: "checkmark.circle", color: .blue) {
                    viewModel.respondToApproval(requestId: approval.id, action: .alwaysAllow)
                }
            }
        }
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var typeBadge: String {
        switch approval.type {
        case .question: return L10n.app("agent.approval.badge.question", fallback: "选择")
        case .permission: return L10n.app("agent.approval.badge.permission", fallback: "权限")
        case .planExit: return L10n.app("agent.approval.badge.plan", fallback: "计划")
        case .toolUse: return L10n.app("agent.approval.badge.tool", fallback: "工具")
        case .askUserQuestionInfo: return L10n.app("agent.approval.badge.terminal", fallback: "终端")
        }
    }

    private var riskColor: Color {
        switch approval.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}
