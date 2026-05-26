import SwiftUI
import Combine

struct AgentHaloExpandedView: View {
    @ObservedObject var viewModel: AgentHaloViewModel
    @ObservedObject var conversationMonitor: ConversationMonitor
    @ObservedObject var gitStatusMonitor: GitStatusMonitor
    @ObservedObject var devServerMonitor: DevServerMonitor
    @ObservedObject var buddyEngine: CatAnimationEngine
    @StateObject private var keyNav = KeyboardNavigationState()
    @Environment(\.notchScale) var scale
    @State private var selectedSessionId: String?
    @State private var searchText = ""
    @State private var hoveredSessionId: String?

    private var selectedSession: AgentSession? {
        if let id = selectedSessionId {
            return viewModel.state.visibleSessions.first(where: { $0.id == id })
                ?? viewModel.state.completedSessions.first(where: { $0.id == id })
        }
        return viewModel.state.visibleSessions.first
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().opacity(0.15)

            if viewModel.state.visibleSessions.isEmpty && viewModel.state.completedSessions.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    sidebar
                    Divider().opacity(0.1)
                    mainContent
                }
            }
        }
        .padding(.top, 8)
        .onAppear {
            keyNav.viewModel = viewModel
            keyNav.activate()
            if selectedSessionId == nil {
                selectedSessionId = viewModel.state.visibleSessions.first?.id
            }
        }
        .onChange(of: viewModel.state.visibleSessions.count) { _, count in
            keyNav.clampIndex(to: count)
            if selectedSessionId == nil, let first = viewModel.state.visibleSessions.first {
                selectedSessionId = first.id
            }
        }
        .background(KeyboardEventView(keyNav: keyNav))
    }

    // MARK: - Header

    @State private var crabBounce: CGFloat = 1.0
    @State private var crabTapTimestamps: [Date] = []
    @State private var soundEnabled: Bool = SoundManager.shared.isEnabled
    @Environment(\.openWindow) private var openWindow

    private var panelHeader: some View {
        HStack(spacing: 8) {
            PixelCatView(mood: .idle, engine: buddyEngine)
                .scaleEffect(0.85 * crabBounce)
                .onTapGesture(count: 2) {
                    buddyEngine.dance()
                    triggerCrabBounce()
                }
                .onTapGesture(count: 1) {
                    handleCrabTap()
                }
                .onLongPressGesture(minimumDuration: 1.5) {
                    buddyEngine.cuddle()
                    triggerCrabBounce()
                }

            Spacer()

            if viewModel.state.displayedActiveSessions.count > 0 {
                Text(L10n.app("agent.header.activeCount", fallback: "%d active").replacingOccurrences(of: "%d", with: "\(viewModel.state.displayedActiveSessions.count)"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Button {
                soundEnabled.toggle()
                SoundManager.shared.isEnabled = soundEnabled
            } label: {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(soundEnabled ? 0.6 : 0.3))
            }
            .buttonStyle(.plain)

            Button {
                if !SettingsWindowCoordinator.activateExisting() {
                    openWindow(id: WindowsScene.settings)
                    SettingsWindowCoordinator.activate()
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func handleCrabTap() {
        let now = Date()
        crabTapTimestamps.append(now)
        crabTapTimestamps = crabTapTimestamps.filter { now.timeIntervalSince($0) < 2 }
        if crabTapTimestamps.count >= 4 {
            buddyEngine.showTemporaryScene(.dizzy, duration: 2.0)
            crabTapTimestamps = []
        } else {
            buddyEngine.pet()
        }
        triggerCrabBounce()
    }

    private func triggerCrabBounce() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            crabBounce = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                crabBounce = 1.0
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.1)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(filteredSessions) { session in
                        sidebarRow(session: session, isActive: true)
                    }

                    if !filteredCompletedSessions.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.25))
                            Text(L10n.app("agent.section.completed", fallback: "Completed"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.25))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                        ForEach(filteredCompletedSessions.prefix(3)) { session in
                            sidebarRow(session: session, isActive: false)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 210)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
            TextField(L10n.app("agent.search.placeholder", fallback: "Search sessions..."), text: $searchText)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var filteredSessions: [AgentSession] {
        let sessions = viewModel.state.visibleSessions.filter { $0.agentType != .unknown }
        let deduped = deduplicateSessions(sessions)
        if searchText.isEmpty { return deduped }
        let query = searchText.lowercased()
        return deduped.filter {
            $0.agentType.displayName.lowercased().contains(query) ||
            ($0.workingOn?.lowercased().contains(query) ?? false) ||
            ($0.terminalInfo?.workingDirectory?.lowercased().contains(query) ?? false)
        }
    }

    private var filteredCompletedSessions: [AgentSession] {
        viewModel.state.completedSessions.filter { $0.agentType != .unknown }
    }

    private func deduplicateSessions(_ sessions: [AgentSession]) -> [AgentSession] {
        var seen: [AgentType: AgentSession] = [:]
        var result: [AgentSession] = []
        for session in sessions {
            if session.connectionType == .hooked {
                result.append(session)
                seen[session.agentType] = session
            } else if seen[session.agentType] == nil {
                result.append(session)
                seen[session.agentType] = session
            }
        }
        return result
    }

    private func sidebarRow(session: AgentSession, isActive: Bool) -> some View {
        let isSelected = selectedSessionId == session.id
        let isHovered = hoveredSessionId == session.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedSessionId = session.id
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(sidebarDotColor(session, isActive: isActive).opacity(0.2))
                        .frame(width: 24, height: 24)
                    Image(systemName: session.agentType.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(sidebarDotColor(session, isActive: isActive))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.agentType.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(isActive ? 0.85 : 0.5))
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        if let source = terminalSourceLabel(session) {
                            Image(systemName: terminalSourceIcon(session))
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.25))
                            Text(source)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        if let dir = session.terminalInfo?.workingDirectory {
                            if terminalSourceLabel(session) != nil {
                                Text("·")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                            Text(shortenDir(dir))
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.3))
                        } else if terminalSourceLabel(session) == nil, let task = session.workingOn {
                            Text(task)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.formattedDuration)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))

                    if session.currentApproval != nil {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? .white.opacity(0.1) : isHovered ? .white.opacity(0.05) : .clear)
                    .shadow(color: .black.opacity(isHovered ? 0.2 : 0), radius: isHovered ? 4 : 0, y: 1)
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredSessionId = hovered ? session.id : nil
            }
        }
    }

    private func sidebarDotColor(_ session: AgentSession, isActive: Bool) -> Color {
        guard isActive else { return .gray.opacity(0.4) }
        switch session.status {
        case .working: return .green
        case .waitingApproval: return .orange
        case .error: return .red
        default: return .gray
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let session = selectedSession {
                mainSessionHeader(session)
                Divider().opacity(0.1)
                mainConversationFlow(session)
                    .onAppear { ensureGitMonitoring(session) }
            } else {
                Spacer()
                Text(L10n.app("agent.main.selectSession", fallback: "Select a session"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ensureGitMonitoring(_ session: AgentSession) {
        guard gitStatusMonitor.statuses[session.id] == nil else { return }
        if let dir = session.terminalInfo?.workingDirectory {
            gitStatusMonitor.startMonitoring(sessionId: session.id, directory: dir)
        } else if session.id.hasPrefix("scan-") {
            let pidStr = session.id.replacingOccurrences(of: "scan-", with: "")
            if let pid = Int32(pidStr) {
                gitStatusMonitor.tryStartFromPID(sessionId: session.id, pid: pid)
            }
        }
    }

    private func mainSessionHeader(_ session: AgentSession) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(mainStatusColor(session).opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: session.agentType.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(mainStatusColor(session))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.agentType.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 4) {
                    if let source = terminalSourceLabel(session) {
                        HStack(spacing: 3) {
                            Image(systemName: terminalSourceIcon(session))
                                .font(.system(size: 8))
                            Text(source)
                        }
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.45))
                    }
                    if let dir = session.terminalInfo?.workingDirectory {
                        if terminalSourceLabel(session) != nil {
                            Text("·")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        Text(shortenDir(dir))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .lineLimit(1)
            }

            Spacer()

            statusPill(session)

            Text(session.formattedDuration)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Button {
                guard let info = session.terminalInfo else { return }
                TerminalJumpEngine.shared.jump(to: info)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(L10n.app("agent.action.jumpToTerminal", fallback: "Jump to Terminal"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func statusPill(_ session: AgentSession) -> some View {
        let (text, color) = statusInfo(session)
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.1))
        )
    }

    private func statusInfo(_ session: AgentSession) -> (String, Color) {
        switch session.status {
        case .working: return ("Working", .green)
        case .waitingApproval: return ("Waiting", .orange)
        case .error: return ("Error", .red)
        case .starting: return ("Starting", .cyan)
        case .done, .completing: return ("Done", .gray)
        case .interrupted: return ("Stopped", .gray)
        case .idle: return ("Idle", .gray)
        }
    }

    private func mainConversationFlow(_ session: AgentSession) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            ScrollViewReader { proxy in
                LazyVStack(alignment: .leading, spacing: 10) {
                    progressSection(session)

                    if let gitInfo = gitStatusMonitor.statuses[session.id], gitInfo.isGitRepo {
                        gitStatusSection(gitInfo)
                    }

                    if !devServerMonitor.servers.isEmpty {
                        devServerSection
                    }

                    if let approval = session.currentApproval {
                        approvalInline(approval)
                            .id("approval-\(approval.id)")
                    }

                    if let conversation = conversationMonitor.conversations[session.id],
                       conversation.isMonitoring {
                        sectionCard {
                            sectionHeader(icon: "bubble.left.and.bubble.right", title: L10n.app("agent.section.conversation", fallback: "Conversation"))

                            ForEach(conversation.messages.suffix(8)) { msg in
                                conversationRow(msg)
                                    .id(msg.id)
                            }

                            if let tool = conversation.currentToolUse ?? session.workingOn {
                                toolActivityRow(tool)
                                    .id("current-tool")
                            }
                        }
                    } else {
                        fallbackToolHistory(session)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func progressSection(_ session: AgentSession) -> some View {
        sectionCard {
            sectionHeader(icon: "chart.bar.fill", title: L10n.app("agent.section.progress", fallback: "Progress"))

            HStack(spacing: 8) {
                if let usage = session.tokenUsage {
                    statBadge(icon: "textformat.size", value: usage.formattedTokens, label: "tokens")
                }
                if let model = session.model {
                    statBadge(icon: "cpu", value: model, label: "model")
                }
                statBadge(icon: "clock", value: session.formattedDuration, label: L10n.app("agent.stat.elapsed", fallback: "elapsed"))

                if session.subAgentCount > 0 {
                    statBadge(icon: "person.2", value: "\(session.subAgentCount)", label: "sub-agents")
                }
            }

            if let workingOn = session.workingOn {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                        .overlay(
                            Circle()
                                .fill(.green.opacity(0.4))
                                .frame(width: 9, height: 9)
                        )
                    Text(workingOn)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }

            if let dir = session.terminalInfo?.workingDirectory {
                gitInfoRow(dir)
            }
        }
    }

    private func gitInfoRow(_ directory: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.purple.opacity(0.7))
            Text(shortenDir(directory))
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.top, 4)
    }

    private func gitStatusSection(_ info: GitStatusInfo) -> some View {
        sectionCard {
            sectionHeader(icon: "arrow.triangle.branch", title: "Git")

            // Branch row
            gitRow(icon: "arrow.triangle.branch", iconColor: .purple, label: info.branch) {
                if info.hasRemote {
                    if info.aheadCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 7, weight: .bold))
                            Text("\(info.aheadCount)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.green.opacity(0.8))
                    }
                    if info.behindCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 7, weight: .bold))
                            Text("\(info.behindCount)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.orange.opacity(0.8))
                    }
                }
            }

            // Changes row
            if info.totalChanges > 0 {
                gitRow(icon: "pencil.circle", iconColor: .orange,
                       label: "\(info.totalChanges) \(L10n.app("agent.git.changes", fallback: "changes"))") {
                    if info.stagedFiles > 0 {
                        gitCountBadge(count: info.stagedFiles, color: .green, icon: "plus.circle.fill")
                    }
                    if info.changedFiles > 0 {
                        gitCountBadge(count: info.changedFiles, color: .orange, icon: "pencil.circle.fill")
                    }
                    if info.untrackedFiles > 0 {
                        gitCountBadge(count: info.untrackedFiles, color: .gray, icon: "questionmark.circle.fill")
                    }
                }
            } else {
                gitRow(icon: "checkmark.circle", iconColor: .green,
                       label: L10n.app("agent.git.clean", fallback: "Clean")) {
                    EmptyView()
                }
            }

            // Stash row
            if info.stashCount > 0 {
                gitRow(icon: "tray.full", iconColor: .cyan,
                       label: "\(info.stashCount) stash\(info.stashCount > 1 ? "es" : "")") {
                    EmptyView()
                }
            }

            // Last commit row
            if let msg = info.lastCommitMessage {
                gitRow(icon: "clock.arrow.circlepath", iconColor: .white.opacity(0.4), label: msg) {
                    if let time = info.lastCommitTimeAgo {
                        Text(time)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
    }

    private func gitRow<Trailing: View>(icon: String, iconColor: Color, label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(iconColor.opacity(0.8))
                .frame(width: 14)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer()
            trailing()
        }
        .padding(.vertical, 1)
    }

    private func gitCountBadge(count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color.opacity(0.8))
            Text("\(count)")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(color.opacity(0.9))
        }
    }

    private var devServerSection: some View {
        sectionCard {
            sectionHeader(icon: "globe", title: L10n.app("agent.section.browser", fallback: "Browser"))

            ForEach(devServerMonitor.servers) { server in
                Button {
                    if let url = URL(string: server.url) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.cyan.opacity(0.8))
                        Text(server.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text("127.0.0.1:\(server.port)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.6))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.04), lineWidth: 0.5)
        )
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 6)
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    private func conversationRow(_ msg: ConversationMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.role == .user {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 20, height: 20)
                    Text(L10n.app("agent.conversation.you", fallback: "You"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.blue.opacity(0.9))
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 20, height: 20)
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                        .foregroundStyle(.purple.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(msg.text)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(msg.role == .user ? 0.9 : 0.75))
                    .lineLimit(msg.role == .user ? 4 : 8)
                    .textSelection(.enabled)

                if let tool = msg.toolName {
                    HStack(spacing: 4) {
                        Image(systemName: toolIcon(tool))
                            .font(.system(size: 8))
                        Text(tool)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.green.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(msg.role == .user ? Color.blue.opacity(0.07) : Color.clear)
        )
    }

    private func toolActivityRow(_ tool: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.6)

            Text(tool)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.green.opacity(0.7))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.green.opacity(0.04))
        )
    }

    private func approvalInline(_ approval: AgentApprovalRequest) -> some View {
        ApprovalCardView(approval: approval, viewModel: viewModel)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.orange.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }

    private func fallbackToolHistory(_ session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let workingOn = session.workingOn {
                sectionCard {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.6)
                        Text(workingOn)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
            }

            if !session.toolHistory.isEmpty {
                let isScanned = session.connectionType == .scanned
                let filteredHistory = session.toolHistory.filter { record in
                    guard record.tool == "Process" else { return true }
                    let noise = ["screencapture", "mdworker", "mds", "kernel", "launchd", "WindowServer", "syslogd"]
                    if let cmd = record.command {
                        return !noise.contains(where: { cmd.contains($0) })
                    }
                    return true
                }

                if !filteredHistory.isEmpty {
                    sectionCard {
                        sectionHeader(
                            icon: isScanned ? "cpu" : "wrench.and.screwdriver",
                            title: isScanned
                                ? L10n.app("agent.section.childProcesses", fallback: "Activity")
                                : L10n.app("agent.section.recentTools", fallback: "Recent Tools")
                        )

                        ForEach(Array(filteredHistory.suffix(10).enumerated()), id: \.offset) { _, record in
                            let displayTool = record.tool == "Process" ? (record.command?.split(separator: " ").first.map(String.init) ?? "Process") : record.tool
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(toolStatusColor(record.status).opacity(0.12))
                                        .frame(width: 18, height: 18)
                                    Image(systemName: toolIcon(displayTool))
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(toolStatusColor(record.status))
                                }
                                Text(displayTool)
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                                if let path = record.filePath {
                                    Text(shortenPath(path))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .lineLimit(1)
                                } else if let cmd = record.command, record.tool != "Process" {
                                    Text(cmd.prefix(60).description)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .lineLimit(1)
                                } else if let cmd = record.command {
                                    let parts = cmd.split(separator: " ").dropFirst()
                                    if !parts.isEmpty {
                                        Text(parts.joined(separator: " ").prefix(60).description)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.4))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            if session.toolHistory.isEmpty && session.workingOn == nil {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.white.opacity(0.12))
                    Text(L10n.app("agent.main.waitingActivity", fallback: "Waiting for activity..."))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white.opacity(0.12))
            Text(L10n.app("agent.empty.title", fallback: "No Active Agents"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text(L10n.app("agent.empty.subtitle", fallback: "Start an AI coding tool to see it here"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.2))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func mainStatusColor(_ session: AgentSession) -> Color {
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

    private func terminalSourceLabel(_ session: AgentSession) -> String? {
        if let app = session.terminalInfo?.terminalApp, !app.isEmpty {
            return app
        }
        switch session.connectionType {
        case .transcript: return "Transcript"
        default: return nil
        }
    }

    private func terminalSourceIcon(_ session: AgentSession) -> String {
        if session.terminalInfo?.terminalApp != nil {
            return "app.terminal"
        }
        switch session.connectionType {
        case .transcript: return "doc.text.magnifyingglass"
        case .scanned: return "cpu"
        default: return "app.terminal"
        }
    }

    private func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 2 {
            return "…/" + components.suffix(2).joined(separator: "/")
        }
        return path
    }

    private func toolIcon(_ tool: String) -> String {
        switch tool.lowercased() {
        case "read": return "doc.text"
        case "write", "edit": return "pencil"
        case "bash": return "terminal"
        case "grep", "glob": return "magnifyingglass"
        case "agent": return "person.2"
        case "webfetch", "websearch": return "globe"
        default: return "wrench"
        }
    }

    private func toolStatusColor(_ status: ToolCallStatus) -> Color {
        switch status {
        case .completed: return .green
        case .running: return .cyan
        case .failed: return .red
        }
    }
}

// MARK: - Approval Card

private struct ApprovalCardView: View {
    let approval: AgentApprovalRequest
    let viewModel: AgentHaloViewModel
    @State private var showFullDiff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            approvalHeader
            approvalContent
            actionButtons
        }
    }

    private var approvalHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(riskColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(approval.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let tool = approval.toolName {
                    Text(tool)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(approval.type.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))
        }
    }

    @ViewBuilder
    private var approvalContent: some View {
        if let command = approval.bashCommand {
            bashCommandView(command)
        }
        if let diff = approval.diff {
            diffPreview(diff)
        }
        if let question = approval.question {
            QuestionInlineView(question: question, approvalId: approval.id, viewModel: viewModel)
        }
        if approval.bashCommand == nil && approval.diff == nil && approval.question == nil {
            Text(approval.description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private func bashCommandView(_ command: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(command)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
    }

    private func diffPreview(_ diff: AgentDiffContent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFullDiff.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                    Text(diff.filePath)
                        .font(.system(size: 10, design: .monospaced))
                    Spacer()
                    Image(systemName: showFullDiff ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if showFullDiff {
                DiffPreviewView(diff: diff)
                    .frame(maxHeight: 200)
            } else {
                compactDiffSummary(diff)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
    }

    private func compactDiffSummary(_ diff: AgentDiffContent) -> some View {
        HStack(spacing: 8) {
            let additions = diff.hunks.flatMap(\.lines).filter { $0.type == .addition }.count
            let deletions = diff.hunks.flatMap(\.lines).filter { $0.type == .deletion }.count
            if additions > 0 {
                Text("+\(additions)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)
            }
            if deletions > 0 {
                Text("-\(deletions)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Spacer()
            if approval.type != .question {
                approvalButton(L10n.app("agent.approval.deny", fallback: "Deny"), icon: "xmark", color: .red) {
                    viewModel.respondToApproval(requestId: approval.id, action: .deny)
                }
                approvalButton(L10n.app("agent.approval.allow", fallback: "Allow"), icon: "checkmark", color: .green) {
                    viewModel.respondToApproval(requestId: approval.id, action: .allow)
                }
                approvalButton(L10n.app("agent.approval.always", fallback: "Always"), icon: "checkmark.circle", color: .blue) {
                    viewModel.respondToApproval(requestId: approval.id, action: .alwaysAllow)
                }
            }
        }
    }

    private func approvalButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var riskColor: Color {
        switch approval.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Question Inline View

private struct QuestionInlineView: View {
    let question: AgentQuestionContent
    let approvalId: String
    let viewModel: AgentHaloViewModel
    @State private var selectedOptions: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)

            VStack(spacing: 4) {
                ForEach(question.options) { option in
                    optionRow(option)
                }
            }

            HStack {
                Spacer()
                Button {
                    viewModel.respondToApproval(
                        requestId: approvalId,
                        action: .answer(selectedOptions: Array(selectedOptions))
                    )
                } label: {
                    Text(L10n.app("agent.approval.submit", fallback: "Submit"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedOptions.isEmpty)
                .opacity(selectedOptions.isEmpty ? 0.5 : 1)
            }
        }
    }

    private func optionRow(_ option: AgentQuestionOption) -> some View {
        let isSelected = selectedOptions.contains(option.id)
        return Button {
            if question.isMultiSelect {
                if isSelected { selectedOptions.remove(option.id) }
                else { selectedOptions.insert(option.id) }
            } else {
                selectedOptions = [option.id]
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected
                    ? (question.isMultiSelect ? "checkmark.square.fill" : "circle.inset.filled")
                    : (question.isMultiSelect ? "square" : "circle")
                )
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                    if let desc = option.description {
                        Text(desc)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard Event Capture

private struct KeyboardEventView: NSViewRepresentable {
    let keyNav: KeyboardNavigationState

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = { [weak keyNav] event in
            guard let keyNav else { return false }
            return keyNav.handleKey(event)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}
}

final class KeyCaptureNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
