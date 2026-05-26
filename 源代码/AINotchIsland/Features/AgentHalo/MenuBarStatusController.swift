import SwiftUI
import Combine

@MainActor
final class MenuBarStatusController: ObservableObject {
    static let shared = MenuBarStatusController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    weak var viewModel: AgentHaloViewModel?

    func setup(viewModel: AgentHaloViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        viewModel.state.$globalStatus
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        // Listen to sessions, but only redraw when the *count* changes —
        // the array updates on every tool-history append, which on a
        // busy hooked session is ~10 Hz. Re-rendering the 18×18 bitmap
        // at that rate is wasted work; the status bar only cares about
        // the visible count and color.
        viewModel.state.$sessions
            .map { $0.count }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button, let vm = viewModel else { return }
        let status = vm.state.globalStatus
        let count = vm.state.activeCount

        // Custom-rendered pixel crab. Template mode = true so macOS
        // auto-tints to the menu bar's foreground color (white in dark
        // bar, black in light bar), matching SF Symbol behaviour.
        // imageScaling = .none keeps our integer pixel grid intact —
        // without this NSStatusBarButton resamples to its own glyph
        // height, and the half-pixel offsets blur the pixel art into
        // an unreadable smear.
        button.image = Self.renderIcon(for: status)
        button.image?.isTemplate = true
        button.imageScaling = .scaleNone
        button.contentTintColor = nil
        button.title = count > 0 ? " \(count)" : ""
    }

    private static func renderIcon(for status: AgentGlobalStatus) -> NSImage {
        _ = status

        let sprite: [[Int]] = [
            [0,0,1,0,0,0,0,0,1,0,0],
            [0,0,0,1,0,0,0,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,0,1,1,1,0,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [1,0,1,1,1,1,1,1,1,0,1],
            [1,0,1,0,0,0,0,0,1,0,1],
            [0,0,0,1,1,0,1,1,0,0,0],
        ]
        let rows = sprite.count
        let cols = sprite[0].count

        // Canvas locked to 18×18pt — the standard macOS menu bar glyph
        // box. NSStatusBarButton will NOT resize a same-sized image, so
        // our pixel grid stays sharp. Sprite is centered inside.
        // cellPt = 1.5 → 3 device pixels per cell on Retina = integer,
        // no half-pixel offsets means no antialiasing artifacts.
        let canvas = NSSize(width: 18, height: 18)
        let cellPt: CGFloat = 1.5
        let spritePtWidth = CGFloat(cols) * cellPt
        let spritePtHeight = CGFloat(rows) * cellPt
        let originX = (canvas.width - spritePtWidth) / 2
        let originY = (canvas.height - spritePtHeight) / 2

        let image = NSImage(size: canvas)
        image.lockFocusFlipped(false)
        defer { image.unlockFocus() }

        if let ctx = NSGraphicsContext.current {
            ctx.shouldAntialias = false
            ctx.imageInterpolation = .none
        }

        NSColor.white.setFill()
        for r in 0..<rows {
            for c in 0..<cols where sprite[r][c] == 1 {
                let rect = NSRect(
                    x: originX + CGFloat(c) * cellPt,
                    y: originY + CGFloat(rows - 1 - r) * cellPt,
                    width: cellPt,
                    height: cellPt
                )
                rect.fill()
            }
        }
        return image
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let vm = viewModel else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
            self.popover = nil
            return
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 300, height: 420)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(viewModel: vm)
        )
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = pop
    }
}

struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: AgentHaloViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.state.activeSessions.isEmpty {
                Spacer()
                Text(L10n.app("agent.menuBar.noActive", fallback: "No active agents"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.state.activeSessions) { session in
                            menuBarSessionRow(session)
                        }
                    }
                    .padding(10)
                }
            }
            Divider()
            footer
        }
        .frame(width: 300, height: 420)
    }

    private var header: some View {
        HStack {
            Text("AINotchIsland")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if !viewModel.state.pendingApprovals.isEmpty {
                Button("Approve All") {
                    for a in viewModel.state.pendingApprovals {
                        viewModel.respondToApproval(requestId: a.id, action: .allow)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(10)
    }

    // Surfaces the app-level commands that used to live in the standalone
    // MenuBarExtra menu. Merging here removed the duplicate status bar
    // icon while keeping every entry point a click away.
    private var footer: some View {
        VStack(spacing: 0) {
            Text(verbatim: localizedVersionText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
                .padding(.bottom, 4)

            footerButton(
                label: L10n.app("settings.title", fallback: "Settings"),
                systemImage: "gearshape"
            ) {
                if !SettingsWindowCoordinator.activateExisting() {
                    openWindow(id: WindowsScene.settings)
                    SettingsWindowCoordinator.activate()
                }
            }

            Divider().padding(.vertical, 2)

            footerButton(
                label: L10n.app("menu.restart", fallback: "Restart"),
                systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90"
            ) {
                AppRelauncher.restartApp()
            }

            footerButton(
                label: L10n.app("menu.quit", fallback: "Quit"),
                systemImage: "rectangle.portrait.and.arrow.right"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func footerButton(
        label: String,
        systemImage: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private var localizedVersionText: String {
        let appLanguage = AINotchIslandLanguage.resolved(
            UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage)
        )
        return appLanguage.locale.dnFormat(
            "Version: %@",
            fallback: "Version: %@",
            AppVersionText.appVersionText
        )
    }

    private func menuBarSessionRow(_ session: AgentSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(session.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.agentType.displayName)
                    .font(.system(size: 11, weight: .semibold))
                Text(session.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 4) {
                Button { _ = viewModel.jumpToTerminal(for: session) } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                Button { viewModel.killSession(session) } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
    }

    private func statusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .working: return .green
        case .waitingApproval: return .orange
        case .error: return .red
        case .starting: return .blue
        default: return .gray
        }
    }
}
