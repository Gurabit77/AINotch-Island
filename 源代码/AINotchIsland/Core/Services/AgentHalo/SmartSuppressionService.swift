import Foundation
internal import AppKit

@MainActor
final class SmartSuppressionService {
    static let shared = SmartSuppressionService()

    private let terminalBundleIds: [String: String] = [
        "iTerm2": "com.googlecode.iterm2",
        "Warp": "dev.warp.Warp-Stable",
        "Ghostty": "com.mitchellh.ghostty",
        "Terminal": "com.apple.Terminal",
        "Cursor": "com.todesktop.230313mzl4w4u92",
        "VS Code": "com.microsoft.VSCode",
        "Alacritty": "org.alacritty",
        "kitty": "net.kovidgoyal.kitty",
        "Hyper": "co.zeit.hyper",
        "WezTerm": "com.github.wez.wezterm",
        "Rio": "com.raphael.rio",
        "Tabby": "org.tabby",
        "Windsurf": "com.codeium.windsurf",
    ]

    func shouldSuppressExpansion(for sessions: [AgentSession]) -> Bool {
        guard UserDefaults.standard.bool(forKey: GeneralSettingsStorage.Keys.agentHaloSmartSuppression) else {
            return false
        }
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
        let frontBundleId = frontmost.bundleIdentifier ?? ""

        return sessions.contains { session in
            guard let terminalApp = session.terminalInfo?.terminalApp else { return false }
            if let knownId = terminalBundleId(for: terminalApp) {
                return knownId == frontBundleId
            }
            return frontmost.localizedName?.lowercased().contains(terminalApp.lowercased()) == true
        }
    }

    private func terminalBundleId(for terminalApp: String) -> String? {
        for (name, bundleId) in terminalBundleIds {
            if terminalApp.localizedCaseInsensitiveContains(name) {
                return bundleId
            }
        }
        return nil
    }
}
