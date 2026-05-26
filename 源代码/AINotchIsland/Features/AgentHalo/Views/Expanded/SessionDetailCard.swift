import SwiftUI
import Combine

struct SessionDetailCard: View {
    let session: AgentSession
    let viewModel: AgentHaloViewModel
    @State private var fileListExpanded = false
    @State private var isHovered = false
    @State private var durationTick = false
    @Environment(\.colorScheme) var colorScheme

    private let durationTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var fileChanges: [FileChange] {
        FileChangeExtractor.extract(from: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if let task = session.workingOn {
                Text(task)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
            if !fileChanges.isEmpty {
                Divider().opacity(0.1).padding(.horizontal, 8)
                fileChangesList
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 6 : 2, y: 1)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovered = h } }
        .onReceive(durationTimer) { _ in durationTick.toggle() }
        .contextMenu {
            if session.terminalInfo != nil {
                Button(L10n.app("agent.session.jumpToTerminal", fallback: "Jump to Terminal")) { _ = viewModel.jumpToTerminal(for: session) }
            }
            if let dir = session.terminalInfo?.workingDirectory {
                Button(L10n.app("agent.session.copyPath", fallback: "Copy Path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(dir, forType: .string)
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: session.agentType.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor)
            Text(session.agentType.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            if let terminal = session.terminalInfo?.terminalApp {
                Text("·")
                    .foregroundStyle(.white.opacity(0.25))
                Text(terminal)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
            if let dir = session.terminalInfo?.workingDirectory {
                Text("·")
                    .foregroundStyle(.white.opacity(0.25))
                Text(shortenDir(dir))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
            Spacer()
            let _ = durationTick
            Text(session.formattedDuration)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor.opacity(0.8))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - File Changes

    private var fileChangesList: some View {
        let visibleFiles = fileListExpanded ? fileChanges : Array(fileChanges.prefix(3))
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(visibleFiles) { change in
                fileRow(change)
            }
            if fileChanges.count > 3 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { fileListExpanded.toggle() }
                } label: {
                    Text(fileListExpanded ? L10n.app("agent.session.collapse", fallback: "▲ Collapse") : "▼ \(fileChanges.count - 3) \(L10n.app("agent.session.moreFiles", fallback: "more files"))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    private func fileRow(_ change: FileChange) -> some View {
        HStack(spacing: 6) {
            Image(systemName: change.isNew ? "doc.badge.plus" : "doc.text")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 14)
            Text(change.shortPath)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            Spacer()
            if change.additions > 0 {
                Text("+\(change.additions)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.8))
            }
            if change.deletions > 0 {
                Text("-\(change.deletions)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch session.status {
        case .working: return .green
        case .waitingApproval: return .orange
        case .error: return .red
        default: return .gray
        }
    }

    private func shortenDir(_ path: String) -> String {
        let parts = path.split(separator: "/")
        guard parts.count > 2 else { return path }
        return parts.suffix(2).joined(separator: "/")
    }
}
