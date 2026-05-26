import Foundation

enum ConversationRole: String, Codable {
    case user
    case assistant
}

struct ConversationMessage: Identifiable, Equatable {
    let id: String
    let role: ConversationRole
    let text: String
    let timestamp: Date
    let toolName: String?

    static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct SessionConversation: Equatable {
    var messages: [ConversationMessage] = []
    var lastUserPrompt: String?
    var lastAssistantText: String?
    var currentToolUse: String?
    var isMonitoring: Bool = false

    static func == (lhs: SessionConversation, rhs: SessionConversation) -> Bool {
        lhs.messages.map(\.id) == rhs.messages.map(\.id) &&
        lhs.lastUserPrompt == rhs.lastUserPrompt &&
        lhs.lastAssistantText == rhs.lastAssistantText &&
        lhs.currentToolUse == rhs.currentToolUse
    }
}
