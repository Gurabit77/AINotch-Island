import Foundation

// MARK: - Tool Call Tracking

enum ToolCallStatus: Equatable {
    case running, completed, failed
}

struct ToolCallRecord: Identifiable, Equatable {
    let id = UUID()
    let tool: String
    let command: String?
    let filePath: String?
    let timestamp: Date
    var status: ToolCallStatus

    static func == (lhs: ToolCallRecord, rhs: ToolCallRecord) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

struct TokenUsage: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0

    var totalTokens: Int { inputTokens + outputTokens }

    var estimatedCost: Double {
        Double(inputTokens) * 0.003 / 1000 + Double(outputTokens) * 0.015 / 1000
    }

    var formattedTokens: String {
        if totalTokens >= 1000 {
            return String(format: "%.1fk", Double(totalTokens) / 1000)
        }
        return "\(totalTokens)"
    }
}

// MARK: - Session

struct AgentSession: Identifiable, Equatable {
    let id: String
    var agentType: AgentType
    var status: AgentSessionStatus
    var title: String
    var workingOn: String?
    var currentApproval: AgentApprovalRequest?
    var subAgentCount: Int = 0
    var pid: Int32? = nil
    var processDetected: Bool = false
    var connectionType: AgentConnectionType = .scanned
    var lastProcessSeen: Date?
    var startedAt: Date
    var lastUpdated: Date
    var terminalInfo: AgentTerminalInfo?
    var toolHistory: [ToolCallRecord] = []
    var tokenUsage: TokenUsage?
    var model: String?

    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        let seconds = Int(duration)
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h\((seconds % 3600) / 60)m"
    }

    var recentToolsSummary: String {
        toolHistory.suffix(5).map { $0.tool }.joined(separator: " → ")
    }

    static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.lastUpdated == rhs.lastUpdated
    }
}

// MARK: - Enums

enum AgentSessionStatus: String, Codable, CaseIterable {
    case idle = "Idle"
    case starting = "Starting"
    case working = "Working"
    case waitingApproval = "Waiting"
    case completing = "Completing"
    case done = "Done"
    case error = "Error"
    case interrupted = "Interrupted"
}

enum AgentConnectionType: String, Codable {
    case hooked
    case scanned
    case detected
    case transcript

    var label: String {
        switch self {
        case .hooked: return "hooked"
        case .scanned: return "scanned"
        case .detected: return "detected"
        case .transcript: return "transcript"
        }
    }
}

enum AgentType: String, Codable, CaseIterable {
    case claudeCode
    case codex
    case geminiCLI
    case cursor
    case openCode
    case droid
    case qoder
    case qwen
    case kimiCode
    case deepSeek
    case copilot
    case codeBuddy
    case kiro
    case hermes
    case openClaw
    case amp
    case piAgent
    case windsurf
    case aider
    case trae
    case mimoCode
    case claudeDesktop
    case chatGPT
    case unknown

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .geminiCLI: return "Gemini CLI"
        case .cursor: return "Cursor"
        case .openCode: return "OpenCode"
        case .droid: return "Droid"
        case .qoder: return "Qoder"
        case .qwen: return "Qwen Code"
        case .kimiCode: return "Kimi Code"
        case .deepSeek: return "DeepSeek"
        case .copilot: return "Copilot CLI"
        case .codeBuddy: return "CodeBuddy"
        case .kiro: return "Kiro"
        case .hermes: return "Hermes"
        case .openClaw: return "OpenClaw"
        case .amp: return "Amp"
        case .piAgent: return "Pi Agent"
        case .windsurf: return "Windsurf"
        case .aider: return "Aider"
        case .trae: return "TRAE"
        case .mimoCode: return "MiMo Code"
        case .claudeDesktop: return "Claude Desktop"
        case .chatGPT: return "ChatGPT"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .claudeCode: return "brain.head.profile"
        case .claudeDesktop: return "brain"
        case .codex: return "terminal"
        case .geminiCLI: return "sparkles"
        case .cursor: return "cursorarrow.rays"
        case .openCode: return "chevron.left.forwardslash.chevron.right"
        case .deepSeek: return "magnifyingglass"
        case .copilot: return "airplane"
        case .kiro: return "bolt.fill"
        case .hermes: return "message.fill"
        case .openClaw: return "ant.fill"
        case .windsurf: return "wind"
        case .aider: return "wrench.and.screwdriver"
        case .trae: return "rays"
        case .mimoCode: return "m.circle"
        case .amp: return "bolt.horizontal.fill"
        case .chatGPT: return "bubble.left.and.bubble.right"
        default: return "cpu"
        }
    }
}

// MARK: - Terminal Info

struct AgentTerminalInfo: Equatable {
    var terminalApp: String
    var windowId: String?
    var tabId: String?
    var paneId: String?
    var tmuxSession: String?
    var workingDirectory: String?
}
