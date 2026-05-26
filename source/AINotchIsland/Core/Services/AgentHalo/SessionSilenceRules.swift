import Foundation
import Combine

struct SessionSilenceRule: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: Kind
    var pattern: String
    var enabled: Bool

    enum Kind: String, Codable {
        case directory
        case promptPrefix
    }

    init(id: UUID = UUID(), kind: Kind, pattern: String, enabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.pattern = pattern
        self.enabled = enabled
    }
}

@MainActor
final class SessionSilenceStore: ObservableObject {
    static let shared = SessionSilenceStore()
    private static let storageKey = "settings.agentHalo.silenceRules"

    @Published private(set) var rules: [SessionSilenceRule] = []

    init() {
        load()
    }

    func add(_ rule: SessionSilenceRule) {
        rules.append(rule)
        persist()
    }

    func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    func toggle(id: UUID) {
        guard let idx = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[idx].enabled.toggle()
        persist()
    }

    func shouldSilence(_ session: AgentSession) -> Bool {
        let activeRules = rules.filter(\.enabled)
        guard !activeRules.isEmpty else { return false }

        for rule in activeRules {
            switch rule.kind {
            case .directory:
                if let dir = session.terminalInfo?.workingDirectory,
                   dir.localizedCaseInsensitiveContains(rule.pattern) {
                    return true
                }
            case .promptPrefix:
                if let workingOn = session.workingOn,
                   workingOn.lowercased().hasPrefix(rule.pattern.lowercased()) {
                    return true
                }
                if session.title.lowercased().hasPrefix(rule.pattern.lowercased()) {
                    return true
                }
            }
        }
        return false
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SessionSilenceRule].self, from: data) else {
            return
        }
        rules = decoded
    }
}
