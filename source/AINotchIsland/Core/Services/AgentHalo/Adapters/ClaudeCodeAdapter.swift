import Foundation

final class ClaudeCodeAdapter: AgentAdapter {
    let id = "claude-code"
    let displayName = "Claude Code"
    let agentType: AgentType = .claudeCode
    let capabilities: Set<AdapterCapability> = [.hookEvents, .processDetection, .terminalJump, .approvalResponse]

    private let responsePipePath: String = {
        NSHomeDirectory() + "/.agent-halo/run/claude-response.pipe"
    }()

    func parseEvent(raw: Data) -> AgentHookEvent? {
        try? JSONDecoder().decode(AgentHookEvent.self, from: raw)
    }

    func transformPayload(_ event: AgentHookEvent) -> AgentHookEvent {
        event
    }

    func sendApprovalResponse(sessionId: String, requestId: String, response: AgentApprovalResponse) -> AdapterResponseResult {
        let responsePayload: [String: Any]
        switch response {
        case .allow:
            responsePayload = ["requestId": requestId, "action": "allow"]
        case .alwaysAllow:
            responsePayload = ["requestId": requestId, "action": "alwaysAllow"]
        case .deny:
            responsePayload = ["requestId": requestId, "action": "deny"]
        case .answer(let options):
            responsePayload = ["requestId": requestId, "action": "answer", "selectedOptions": options]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: responsePayload),
              let json = String(data: data, encoding: .utf8) else {
            DebugLogWriter.shared.append("[Adapter] serialization failed for \(requestId)\n")
            return .failed(AdapterError.serializationFailed)
        }

        let pipePath = NSHomeDirectory() + "/.agent-halo/run/responses/\(sessionId).pipe"

        // Retry up to 10 times (1s total) to handle race with bridge pipe creation
        var attempts = 0
        while !FileManager.default.fileExists(atPath: pipePath) && attempts < 10 {
            Thread.sleep(forTimeInterval: 0.1)
            attempts += 1
        }

        guard FileManager.default.fileExists(atPath: pipePath) else {
            DebugLogWriter.shared.append("[Adapter] pipe not found after \(attempts) retries: \(pipePath)\n")
            return .unsupported
        }

        do {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: pipePath))
            handle.write((json + "\n").data(using: .utf8)!)
            handle.closeFile()
            DebugLogWriter.shared.append("[Adapter] response sent to pipe: \(sessionId) action=\(response)\n")
            return .sent
        } catch {
            DebugLogWriter.shared.append("[Adapter] pipe write failed: \(error)\n")
            return .failed(error)
        }
    }

    func extractTokenUsage(from event: AgentHookEvent) -> TokenUsage? {
        guard event.type == .sessionEnd else { return nil }
        return nil
    }
}
