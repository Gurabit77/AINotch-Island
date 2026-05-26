import Foundation

enum AgentHookEventType: String, Codable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case stop = "Stop"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case permissionRequest = "PermissionRequest"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let normalized = raw
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        switch normalized {
        case "sessionstart": self = .sessionStart
        case "sessionend": self = .sessionEnd
        case "stop": self = .stop
        case "userpromptsubmit": self = .userPromptSubmit
        case "pretooluse": self = .preToolUse
        case "posttooluse": self = .postToolUse
        case "permissionrequest": self = .permissionRequest
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown event type: \(raw)")
            )
        }
    }
}

struct AgentHookEvent: Codable {
    let type: AgentHookEventType
    let sessionId: String
    let timestamp: TimeInterval
    let agent: String?
    let payload: AgentHookPayload?

    enum CodingKeys: String, CodingKey {
        case type, sessionId, timestamp, agent, payload
    }
}

struct AgentHookPayload: Codable {
    var tool: String?
    var command: String?
    var filePath: String?
    var oldContent: String?
    var newContent: String?
    var diff: String?
    var title: String?
    var description: String?
    var riskLevel: String?
    var question: String?
    var options: [AgentHookQuestionOption]?
    var isMultiSelect: Bool?
    /// Bridge sets this true when forwarding an AskUserQuestion PreToolUse
    /// hook. The island then shows a read-only info card (no approval
    /// buttons) and dismisses it when UserPromptSubmit fires next.
    var askUserQuestionInfo: Bool?
    var status: String?
    var workingOn: String?
    var terminalApp: String?
    var windowId: String?
    var tabId: String?
    var paneId: String?
    var workingDirectory: String?
    var subAgentCount: Int?
    // Bridge-resolved pid of the real agent process (claude / codex / mimo …).
    // Used by AgentHaloState.addSession to merge hooked + scanned cards.
    var pid: Int32?
}

struct AgentHookQuestionOption: Codable {
    let id: String
    let label: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, label, description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try container.decode(String.self, forKey: .label)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? self.label
    }
}

struct AgentHookResponse: Codable {
    let requestId: String
    let action: String
    let selectedOptions: [String]?
}
