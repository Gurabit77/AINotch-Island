import Foundation
import Combine

@MainActor
final class HookInstaller: ObservableObject {
    static let shared = HookInstaller()

    @Published private(set) var hookStatus: [String: HookStatus] = [:]

    private let basePath = NSHomeDirectory() + "/.agent-halo"
    private let binPath: String
    private let bridgeName = "agent-halo-bridge"
    enum HookStatus: String {
        case installed
        case notInstalled
        case error
        case toolNotFound
    }

    private init() {
        binPath = basePath + "/bin"
    }

    func setupIfNeeded() {
        createDirectoryStructure()
        deployBridgeBinary()
        refreshHookStatus()
        autoInstallMissingHooks()
    }

    func installAll() {
        let registry = AgentRegistry.shared.entries
        for entry in registry where entry.hookSupport == .full {
            installHooksFor(source: entry.source)
        }
    }

    private func autoInstallMissingHooks() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let configPaths: [String: String] = [
            "claude": home + "/.claude",
            "codex": home + "/.codex",
            "cursor": home + "/.cursor",
            "amp": home + "/.config/amp"
        ]
        for (source, configPath) in configPaths {
            guard fm.fileExists(atPath: configPath) else { continue }
            if hookStatus[source] == .notInstalled {
                installHooksFor(source: source)
            }
        }
    }

    func uninstallAll() {
        for source in ["claude", "codex", "cursor", "amp"] {
            uninstallHooksFor(source: source)
        }
    }

    func installHooksFor(source: String) {
        switch source {
        case "claude": installClaudeCodeHooks()
        case "codex": installCodexHooks()
        case "cursor": installCursorHooks()
        case "amp": installAmpHooks()
        default: break
        }
        refreshHookStatus()
    }

    func uninstallHooksFor(source: String) {
        switch source {
        case "claude": uninstallClaudeCodeHooks()
        case "codex": uninstallCodexHooks()
        case "cursor": uninstallCursorHooks()
        case "amp": uninstallAmpHooks()
        default: break
        }
        refreshHookStatus()
    }

    func refreshHookStatus() {
        var status: [String: HookStatus] = [:]
        status["claude"] = checkClaudeHookStatus()
        status["codex"] = checkCodexHookStatus()
        status["cursor"] = checkCursorHookStatus()
        status["amp"] = checkAmpHookStatus()
        hookStatus = status
    }

    // MARK: - Directory Setup

    private func createDirectoryStructure() {
        let fm = FileManager.default
        let dirs = [basePath, basePath + "/run", basePath + "/bin", basePath + "/extensions"]
        for dir in dirs {
            if !fm.fileExists(atPath: dir) {
                try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Bridge Binary Deployment

    private func deployBridgeBinary() {
        guard let bundledBridge = Bundle.main.url(forResource: bridgeName, withExtension: nil) else {
            return
        }
        let targetPath = binPath + "/" + bridgeName
        let fm = FileManager.default

        if fm.fileExists(atPath: targetPath) {
            try? fm.removeItem(atPath: targetPath)
        }
        try? fm.copyItem(at: bundledBridge, to: URL(fileURLWithPath: targetPath))
        chmod(targetPath, 0o755)
    }

    // MARK: - Bridge Commands

    private func makeBridgeCommand(source: String) -> String {
        "\(binPath)/\(bridgeName) --source \(source); exit 0"
    }

    private func makeBlockingBridgeCommand(source: String) -> String {
        "\(binPath)/\(bridgeName) --source \(source) --blocking"
    }

    // Informational-only hook types (never block CLI)
    private let claudeHookTypes = [
        "PreToolUse", "PostToolUse", "SessionStart", "SessionEnd",
        "Stop", "UserPromptSubmit", "SubagentStart", "SubagentStop"
    ]

    // MARK: - Claude Code Hooks

    private func installClaudeCodeHooks() {
        let settingsPath = NSHomeDirectory() + "/.claude/settings.json"
        let fm = FileManager.default

        guard fm.fileExists(atPath: NSHomeDirectory() + "/.claude") else { return }

        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        let bridgeCmd = makeBridgeCommand(source: "claude")
        let blockingBridgeCmd = makeBlockingBridgeCommand(source: "claude")

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for hookType in claudeHookTypes {
            var hookEntries = hooks[hookType] as? [[String: Any]] ?? []

            if !containsAgentHaloBridge(in: hookEntries) {
                hookEntries.append([
                    "matcher": "*",
                    "hooks": [
                        ["type": "command", "command": bridgeCmd]
                    ]
                ])
            }
            hooks[hookType] = hookEntries
        }

        var permEntries = hooks["PermissionRequest"] as? [[String: Any]] ?? []
        if !containsAgentHaloBridge(in: permEntries) {
            permEntries.append([
                "matcher": "*",
                "hooks": [
                    ["type": "command", "command": blockingBridgeCmd, "timeout": 86400]
                ]
            ])
        }
        hooks["PermissionRequest"] = permEntries

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func uninstallClaudeCodeHooks() {
        let settingsPath = NSHomeDirectory() + "/.claude/settings.json"
        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for key in hooks.keys {
            if var entries = hooks[key] as? [[String: Any]] {
                entries.removeAll { entryContainsAgentHaloBridge($0) }
                hooks[key] = entries.isEmpty ? nil : entries
            }
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func checkClaudeHookStatus() -> HookStatus {
        let claudeDir = NSHomeDirectory() + "/.claude"
        guard FileManager.default.fileExists(atPath: claudeDir) else { return .toolNotFound }

        let settingsPath = claudeDir + "/settings.json"
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = settings["hooks"] as? [String: Any] else {
            return .notInstalled
        }

        let hasHook = hooks.values.contains { entries in
            guard let arr = entries as? [[String: Any]] else { return false }
            return containsAgentHaloBridge(in: arr)
        }
        return hasHook ? .installed : .notInstalled
    }

    // MARK: - Codex Hooks (TOML inline format)

    private func installCodexHooks() {
        let configDir = NSHomeDirectory() + "/.codex"
        let configTomlPath = configDir + "/config.toml"
        let fm = FileManager.default

        guard fm.fileExists(atPath: configDir) else { return }
        guard fm.fileExists(atPath: configTomlPath) else { return }
        guard var content = try? String(contentsOfFile: configTomlPath, encoding: .utf8) else { return }

        if content.contains("agent-halo-bridge") { return }

        let bridgeCmd = makeBridgeCommand(source: "codex")
        let hookTypes = ["PreToolUse", "PostToolUse", "SessionStart", "SessionEnd", "Stop", "UserPromptSubmit"]

        var tomlBlock = "\n"
        for hookType in hookTypes {
            tomlBlock += "[[hooks.\(hookType)]]\n"
            tomlBlock += "[[hooks.\(hookType).hooks]]\n"
            tomlBlock += "type = \"command\"\n"
            tomlBlock += "command = \"\(bridgeCmd)\"\n"
            tomlBlock += "timeout = 5\n\n"
        }

        if let historyRange = content.range(of: "[history]") {
            content.insert(contentsOf: tomlBlock, at: historyRange.lowerBound)
        } else {
            content += tomlBlock
        }

        try? content.write(toFile: configTomlPath, atomically: true, encoding: .utf8)

        cleanCodexHooksJson()
    }

    private func cleanCodexHooksJson() {
        let hooksJsonPath = NSHomeDirectory() + "/.codex/hooks.json"
        let fm = FileManager.default
        guard let data = fm.contents(atPath: hooksJsonPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else { return }

        var changed = false
        for (key, value) in hooks {
            guard var entries = value as? [[String: Any]] else { continue }
            let before = entries.count
            entries.removeAll { entryContainsAgentHaloBridge($0) }
            if entries.count != before { changed = true }
            hooks[key] = entries.isEmpty ? nil : entries
        }

        guard changed else { return }
        json["hooks"] = hooks

        if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? newData.write(to: URL(fileURLWithPath: hooksJsonPath))
        }
    }

    private func uninstallCodexHooks() {
        let configTomlPath = NSHomeDirectory() + "/.codex/config.toml"
        guard var content = try? String(contentsOfFile: configTomlPath, encoding: .utf8) else { return }

        var lines = content.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            if lines[i].contains("agent-halo-bridge") ||
               (lines[i].hasPrefix("[[hooks.") && i + 1 < lines.count && lines[i + 1].contains("agent-halo-bridge")) {
                let start = max(0, i - 1)
                var end = i
                while end < lines.count && (lines[end].hasPrefix("[[hooks.") || lines[end].starts(with: "type =") || lines[end].starts(with: "command =") || lines[end].starts(with: "timeout =") || lines[end].isEmpty) {
                    end += 1
                    if end < lines.count && lines[end].hasPrefix("[[hooks.") && !lines[end].contains(".hooks]]") { break }
                }
                lines.removeSubrange(start..<end)
                i = start
            } else {
                i += 1
            }
        }
        content = lines.joined(separator: "\n")
        try? content.write(toFile: configTomlPath, atomically: true, encoding: .utf8)
    }

    private func checkCodexHookStatus() -> HookStatus {
        let configDir = NSHomeDirectory() + "/.codex"
        guard FileManager.default.fileExists(atPath: configDir) else { return .toolNotFound }

        let configTomlPath = configDir + "/config.toml"
        guard let content = try? String(contentsOfFile: configTomlPath, encoding: .utf8) else {
            return .notInstalled
        }
        return content.contains("agent-halo-bridge") ? .installed : .notInstalled
    }

    // MARK: - Cursor Hooks

    private func installCursorHooks() {
        let cursorDir = NSHomeDirectory() + "/.cursor"
        guard FileManager.default.fileExists(atPath: cursorDir) else { return }

        let hooksDir = cursorDir + "/hooks"
        try? FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        let bridgeCmd = makeBridgeCommand(source: "cursor")
        let script = "#!/bin/bash\necho \"$CURSOR_HOOK_DATA\" | \(bridgeCmd)\n"

        let scriptPath = hooksDir + "/agent-halo-hook.sh"
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        chmod(scriptPath, 0o755)
    }

    private func uninstallCursorHooks() {
        let scriptPath = NSHomeDirectory() + "/.cursor/hooks/agent-halo-hook.sh"
        try? FileManager.default.removeItem(atPath: scriptPath)
    }

    private func checkCursorHookStatus() -> HookStatus {
        let cursorDir = NSHomeDirectory() + "/.cursor"
        guard FileManager.default.fileExists(atPath: cursorDir) else { return .toolNotFound }

        let scriptPath = cursorDir + "/hooks/agent-halo-hook.sh"
        return FileManager.default.fileExists(atPath: scriptPath) ? .installed : .notInstalled
    }

    // MARK: - Amp Hooks

    private func installAmpHooks() {
        let configDir = NSHomeDirectory() + "/.config/amp"
        let settingsPath = configDir + "/settings.json"
        let fm = FileManager.default

        guard fm.fileExists(atPath: configDir) else { return }

        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        let bridgeCmd = makeBridgeCommand(source: "amp")
        let hookTypes = ["PreToolUse", "PostToolUse", "SessionStart", "SessionEnd", "Stop"]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for hookType in hookTypes {
            var hookEntries = hooks[hookType] as? [[String: Any]] ?? []
            if !containsAgentHaloBridge(in: hookEntries) {
                hookEntries.append([
                    "matcher": "*",
                    "hooks": [["type": "command", "command": bridgeCmd]]
                ])
            }
            hooks[hookType] = hookEntries
        }
        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func uninstallAmpHooks() {
        let settingsPath = NSHomeDirectory() + "/.config/amp/settings.json"
        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for key in hooks.keys {
            if var entries = hooks[key] as? [[String: Any]] {
                entries.removeAll { entryContainsAgentHaloBridge($0) }
                hooks[key] = entries.isEmpty ? nil : entries
            }
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func checkAmpHookStatus() -> HookStatus {
        let configDir = NSHomeDirectory() + "/.config/amp"
        guard FileManager.default.fileExists(atPath: configDir) else { return .toolNotFound }

        let settingsPath = configDir + "/settings.json"
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = settings["hooks"] as? [String: Any] else {
            return .notInstalled
        }

        let hasHook = hooks.values.contains { entries in
            guard let arr = entries as? [[String: Any]] else { return false }
            return containsAgentHaloBridge(in: arr)
        }
        return hasHook ? .installed : .notInstalled
    }

    // MARK: - Helpers

    private func containsAgentHaloBridge(in entries: [[String: Any]]) -> Bool {
        entries.contains { entryContainsAgentHaloBridge($0) }
    }

    private func entryContainsAgentHaloBridge(_ entry: [String: Any]) -> Bool {
        if let cmd = entry["command"] as? String, cmd.contains("agent-halo-bridge") {
            return true
        }
        if let nestedHooks = entry["hooks"] as? [[String: Any]] {
            return nestedHooks.contains { hook in
                (hook["command"] as? String)?.contains("agent-halo-bridge") == true
            }
        }
        return false
    }
}
