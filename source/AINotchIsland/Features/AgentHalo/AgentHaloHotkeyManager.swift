import Cocoa
import Carbon

@MainActor
final class AgentHaloHotkeyManager {
    static let shared = AgentHaloHotkeyManager()

    private var eventMonitors: [Any] = []

    var onToggle: (() -> Void)?
    var onQuickApprove: (() -> Void)?
    var onJumpToTerminal: (() -> Void)?
    var onKillPrimary: (() -> Void)?
    var onDismissApprovals: (() -> Void)?

    private init() {}

    func start() {
        stop()
        registerHotkey(keyCode: 0, callback: { self.onToggle?() })       // Cmd+Shift+A
        registerHotkey(keyCode: 16, callback: { self.onQuickApprove?() }) // Cmd+Shift+Y
        registerHotkey(keyCode: 38, callback: { self.onJumpToTerminal?() }) // Cmd+Shift+J
        registerHotkey(keyCode: 40, callback: { self.onKillPrimary?() })  // Cmd+Shift+K
        registerHotkey(keyCode: 2, callback: { self.onDismissApprovals?() }) // Cmd+Shift+D
    }

    func stop() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }

    private func registerHotkey(keyCode: UInt16, callback: @escaping () -> Void) {
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == keyCode else { return }
            Task { @MainActor in
                callback()
            }
        }
        if let monitor { eventMonitors.append(monitor) }
    }
}
