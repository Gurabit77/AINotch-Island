import Foundation

protocol TranscriptSource: AnyObject {
    var agentType: AgentType { get }
    var isAvailable: Bool { get }
    func discoverActiveSessions() -> [DiscoveredTranscript]
    func parseNewContent(at path: String, from offset: UInt64) -> [TranscriptEntry]
}

struct DiscoveredTranscript {
    let sessionId: String
    let filePath: String
    let agentType: AgentType
    let lastModified: Date
}

struct TranscriptEntry {
    let role: ConversationRole
    let text: String
    let toolName: String?
    let timestamp: Date
}
