import Foundation

class GenericAgentAdapter: AgentAdapter {
    let id: String
    let displayName: String
    let agentType: AgentType
    let capabilities: Set<AdapterCapability> = [.hookEvents, .processDetection, .terminalJump]

    init(id: String, displayName: String, agentType: AgentType) {
        self.id = id
        self.displayName = displayName
        self.agentType = agentType
    }

    func parseEvent(raw: Data) -> AgentHookEvent? {
        try? JSONDecoder().decode(AgentHookEvent.self, from: raw)
    }

    func sendApprovalResponse(sessionId: String, requestId: String, response: AgentApprovalResponse) -> AdapterResponseResult {
        .unsupported
    }

    func extractTokenUsage(from event: AgentHookEvent) -> TokenUsage? {
        nil
    }
}
