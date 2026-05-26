import Foundation

enum AgentHaloEvent: Equatable {
    case agentsActive
    case agentsIdle
    case approvalRequested(requestId: String)
    case approvalResolved(requestId: String)
    case statusChanged(AgentGlobalStatus)
    case toggleRequested
    case terminalJumpFailed(String)
    case sessionCompleted(sessionId: String)
    case toolActivityPeek(session: AgentSession)
}
