import Foundation

enum AdapterError: Error {
    case serializationFailed
    case transportUnavailable
}

final class AdapterRegistry {
    static let shared = AdapterRegistry()

    private var adapters: [String: AgentAdapter] = [:]
    private var agentTypeMap: [AgentType: AgentAdapter] = [:]

    private init() {
        register(ClaudeCodeAdapter())
        register(CodexAdapter())
        register(OpenCodeAdapter())
        register(HermesAdapter())
    }

    func register(_ adapter: AgentAdapter) {
        adapters[adapter.id] = adapter
        agentTypeMap[adapter.agentType] = adapter
    }

    func adapter(for agentType: AgentType) -> AgentAdapter? {
        agentTypeMap[agentType]
    }

    func adapter(byId id: String) -> AgentAdapter? {
        adapters[id]
    }

    func adapter(forSource source: String) -> AgentAdapter? {
        let key = source.lowercased()
        switch key {
        case "claude", "claude-code", "claude_code":
            return agentTypeMap[.claudeCode]
        case "codex":
            return agentTypeMap[.codex]
        case "opencode", "open-code":
            return agentTypeMap[.openCode]
        case "hermes":
            return agentTypeMap[.hermes]
        default:
            return nil
        }
    }

    var allAdapters: [AgentAdapter] {
        Array(adapters.values)
    }

    func capabilities(for agentType: AgentType) -> Set<AdapterCapability> {
        agentTypeMap[agentType]?.capabilities ?? []
    }
}
