import Foundation
internal import AppKit
import os.log

enum TerminalJumpResult {
    case success
    case appNotFound
    case scriptError(String)
}

final class TerminalJumpEngine {
    static let shared = TerminalJumpEngine()

    func jump(to info: AgentTerminalInfo, completion: ((TerminalJumpResult) -> Void)? = nil) {
        switch info.terminalApp.lowercased() {
        case "iterm2", "iterm":
            jumpToITerm2(info, completion: completion)
        case "terminal", "terminal.app":
            jumpToTerminalApp(info, completion: completion)
        case "ghostty":
            activateApp("Ghostty", bundleId: "com.mitchellh.ghostty", completion: completion)
        case "warp":
            activateApp("Warp", bundleId: "dev.warp.Warp-Stable", completion: completion)
        case "code", "vscode", "visual studio code":
            jumpToVSCode(info, completion: completion)
        case "cursor":
            jumpToCursor(info, completion: completion)
        case "kitty":
            activateApp("kitty", bundleId: "net.kovidgoyal.kitty", completion: completion)
        case "wezterm":
            activateApp("WezTerm", bundleId: "com.github.wez.wezterm", completion: completion)
        default:
            activateApp(info.terminalApp, completion: completion)
        }
    }

    private func jumpToITerm2(_ info: AgentTerminalInfo, completion: ((TerminalJumpResult) -> Void)?) {
        guard isAppRunning(bundleId: "com.googlecode.iterm2") else {
            completion?(.appNotFound)
            return
        }

        var script = """
        tell application "iTerm"
            activate
        """

        if let windowId = info.windowId {
            script += """

                set targetWindow to window id \(windowId)
                select targetWindow
            """
        }

        if let tabId = info.tabId {
            script += """

                tell current window
                    select tab \(tabId)
                end tell
            """
        }

        if let paneId = info.paneId {
            script += """

                tell current window
                    tell current tab
                        select session id "\(paneId)"
                    end tell
                end tell
            """
        }

        script += "\nend tell"
        runAppleScript(script, completion: completion)
    }

    private func jumpToTerminalApp(_ info: AgentTerminalInfo, completion: ((TerminalJumpResult) -> Void)?) {
        guard isAppRunning(bundleId: "com.apple.Terminal") else {
            completion?(.appNotFound)
            return
        }

        var script = """
        tell application "Terminal"
            activate
        """

        if let windowId = info.windowId {
            script += """

                set index of window id \(windowId) to 1
            """
        }

        if let tabId = info.tabId {
            script += """

                tell window 1
                    set selected tab to tab \(tabId)
                end tell
            """
        }

        script += "\nend tell"
        runAppleScript(script, completion: completion)
    }

    private func jumpToVSCode(_ info: AgentTerminalInfo, completion: ((TerminalJumpResult) -> Void)?) {
        let bundleId = "com.microsoft.VSCode"
        guard isAppRunning(bundleId: bundleId) else {
            completion?(.appNotFound)
            return
        }

        if let workingDir = info.workingDirectory {
            let script = """
            tell application "Visual Studio Code"
                activate
            end tell
            do shell script "open -a 'Visual Studio Code' '\(workingDir.replacingOccurrences(of: "'", with: "'\\''"))'"
            """
            runAppleScript(script, completion: completion)
        } else {
            activateApp("Visual Studio Code", bundleId: bundleId, completion: completion)
        }
    }

    private func jumpToCursor(_ info: AgentTerminalInfo, completion: ((TerminalJumpResult) -> Void)?) {
        let bundleId = "com.todesktop.230313mzl4w4u92"
        guard isAppRunning(bundleId: bundleId) else {
            if !isAppRunning(name: "Cursor") {
                completion?(.appNotFound)
                return
            }
            activateApp("Cursor", completion: completion)
            return
        }

        if let workingDir = info.workingDirectory {
            let script = """
            tell application "Cursor"
                activate
            end tell
            do shell script "open -a 'Cursor' '\(workingDir.replacingOccurrences(of: "'", with: "'\\''"))'"
            """
            runAppleScript(script, completion: completion)
        } else {
            activateApp("Cursor", bundleId: bundleId, completion: completion)
        }
    }

    private func activateApp(_ name: String, bundleId: String? = nil, completion: ((TerminalJumpResult) -> Void)?) {
        if let bundleId, !isAppRunning(bundleId: bundleId) {
            if !isAppRunning(name: name) {
                completion?(.appNotFound)
                return
            }
        }

        let script = """
        tell application "\(name)"
            activate
        end tell
        """
        runAppleScript(script, completion: completion)
    }

    private func isAppRunning(bundleId: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
    }

    private func isAppRunning(name: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.localizedName?.lowercased() == name.lowercased()
        }
    }

    private func runAppleScript(_ source: String, completion: ((TerminalJumpResult) -> Void)?) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let script = NSAppleScript(source: source) else {
                DispatchQueue.main.async { completion?(.scriptError("Failed to create script")) }
                return
            }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if let error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? error.description
                    AppLogger.agentHalo.error("AppleScript error: \(msg)")
                    completion?(.scriptError(msg))
                } else {
                    completion?(.success)
                }
            }
        }
    }
}
