import Foundation

struct AgentApprovalRequest: Identifiable, Equatable {
    let id: String
    let sessionId: String
    var type: AgentApprovalType
    var title: String
    var description: String
    var riskLevel: AgentRiskLevel
    var toolName: String?
    var filePath: String?
    var diff: AgentDiffContent?
    var bashCommand: String?
    var question: AgentQuestionContent?
    var createdAt: Date

    static func == (lhs: AgentApprovalRequest, rhs: AgentApprovalRequest) -> Bool {
        lhs.id == rhs.id
    }
}

enum AgentApprovalType: String, Codable {
    case permission = "Permission"
    case question = "Question"
    case planExit = "Plan Exit"
    case toolUse = "Tool Use"
    /// AskUserQuestion info card. Read-only: shows the question +
    /// options for reference but exposes no action buttons. Claude has
    /// been told to ask the question as plain text instead, so the user
    /// answers in the terminal. The card is dismissed when the next
    /// UserPromptSubmit hook fires.
    case askUserQuestionInfo = "AskUserQuestionInfo"
}

enum AgentRiskLevel: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct AgentDiffContent: Equatable {
    var filePath: String
    var oldContent: String
    var newContent: String
    var hunks: [AgentDiffHunk]
}

struct AgentDiffHunk: Identifiable, Equatable {
    let id = UUID()
    var oldStart: Int
    var oldCount: Int
    var newStart: Int
    var newCount: Int
    var lines: [AgentDiffLine]
}

struct AgentDiffLine: Identifiable, Equatable {
    let id = UUID()
    var type: AgentDiffLineType
    var content: String
    var lineNumber: Int?
}

enum AgentDiffLineType: Equatable {
    case context
    case addition
    case deletion
    case header
}

struct AgentQuestionContent: Equatable {
    var question: String
    var options: [AgentQuestionOption]
    var isMultiSelect: Bool
}

struct AgentQuestionOption: Identifiable, Equatable {
    let id: String
    var label: String
    var description: String?
    var isSelected: Bool = false
}

enum AgentApprovalResponse {
    case allow
    case alwaysAllow
    case deny
    case answer(selectedOptions: [String])
}
