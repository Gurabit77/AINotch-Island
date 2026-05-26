import SwiftUI

struct SessionDoneCard: View {
    let session: AgentSession
    let viewModel: AgentHaloViewModel
    @State private var isHovered = false

    private var fileChanges: [FileChange] {
        FileChangeExtractor.extract(from: session)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(session.agentType.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    if let terminal = session.terminalInfo?.terminalApp {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                        Text(terminal)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                if let task = session.workingOn {
                    Text(task)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.app("agent.session.doneJump", fallback: "Done · tap to jump →"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.green.opacity(isHovered ? 0.9 : 0.6))
                changeSummary
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.green.opacity(isHovered ? 0.3 : 0), lineWidth: 1)
                )
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovered = h } }
        .onTapGesture { _ = viewModel.jumpToTerminal(for: session) }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder
    private var changeSummary: some View {
        let totalFiles = fileChanges.count
        let totalAdd = fileChanges.reduce(0) { $0 + $1.additions }
        let totalDel = fileChanges.reduce(0) { $0 + $1.deletions }
        if totalFiles > 0 {
            HStack(spacing: 4) {
                Text("\(totalFiles) \(L10n.app("agent.session.fileCount", fallback: totalFiles == 1 ? "file" : "files"))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                if totalAdd > 0 {
                    Text("+\(totalAdd)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.6))
                }
                if totalDel > 0 {
                    Text("-\(totalDel)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.5))
                }
            }
        }
    }
}
