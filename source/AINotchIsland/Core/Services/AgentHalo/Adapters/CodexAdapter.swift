import Foundation

final class CodexAdapter: GenericAgentAdapter {
    init() {
        super.init(id: "codex", displayName: "Codex", agentType: .codex)
    }
}
