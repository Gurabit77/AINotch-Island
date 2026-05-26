import Foundation

enum AdapterCapability {
    case hookEvents
    case approvalResponse
    case tokenUsage
    case processDetection
    case terminalJump
}

enum AdapterResponseResult {
    case sent
    case unsupported
    case failed(Error)
}

protocol AgentAdapter: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var agentType: AgentType { get }
    var capabilities: Set<AdapterCapability> { get }

    func parseEvent(raw: Data) -> AgentHookEvent?
    func transformPayload(_ event: AgentHookEvent) -> AgentHookEvent
    func sendApprovalResponse(sessionId: String, requestId: String, response: AgentApprovalResponse) -> AdapterResponseResult
    func extractTokenUsage(from event: AgentHookEvent) -> TokenUsage?
}

extension AgentAdapter {
    func transformPayload(_ event: AgentHookEvent) -> AgentHookEvent { event }
    func sendApprovalResponse(sessionId: String, requestId: String, response: AgentApprovalResponse) -> AdapterResponseResult { .unsupported }
    func extractTokenUsage(from event: AgentHookEvent) -> TokenUsage? { nil }
}
