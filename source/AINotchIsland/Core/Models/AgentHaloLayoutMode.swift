import Foundation

enum AgentHaloLayoutMode: String, Codable, CaseIterable {
    case clean
    case detailed

    var displayName: String {
        switch self {
        case .clean: return "Clean"
        case .detailed: return "Detailed"
        }
    }

    var description: String {
        switch self {
        case .clean: return "Minimal — only the progress ring and dots"
        case .detailed: return "Shows agent name, task, and duration below the notch"
        }
    }
}
