import Foundation

final class OpenCodeAdapter: GenericAgentAdapter {
    init() {
        super.init(id: "opencode", displayName: "OpenCode", agentType: .openCode)
    }
}
