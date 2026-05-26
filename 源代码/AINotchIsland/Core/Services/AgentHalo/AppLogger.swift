import Foundation
import os.log

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.ainotchisland"

    static let agentHalo = Logger(subsystem: subsystem, category: "AgentHalo")
    static let socket = Logger(subsystem: subsystem, category: "Socket")
    static let scanner = Logger(subsystem: subsystem, category: "Scanner")
    static let hooks = Logger(subsystem: subsystem, category: "Hooks")
    static let extensions = Logger(subsystem: subsystem, category: "Extensions")
    static let bluetooth = Logger(subsystem: subsystem, category: "Bluetooth")
    static let hud = Logger(subsystem: subsystem, category: "HUD")
    static let focus = Logger(subsystem: subsystem, category: "Focus")
    static let timer = Logger(subsystem: subsystem, category: "Timer")
    static let media = Logger(subsystem: subsystem, category: "NowPlaying")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let general = Logger(subsystem: subsystem, category: "General")
}
