import Foundation

struct PersistedSession: Codable {
    let id: String
    let agentType: String
    let status: String
    let title: String
    let workingOn: String?
    let startedAt: Date
    let lastUpdated: Date
    let toolCount: Int
    let tokenUsage: PersistedTokenUsage?
    let model: String?
    let connectionType: String

    struct PersistedTokenUsage: Codable {
        let inputTokens: Int
        let outputTokens: Int
    }
}

@MainActor
final class SessionPersistence {
    static let shared = SessionPersistence()

    private let directory: String = NSHomeDirectory() + "/.agent-halo/sessions"
    private let maxFiles = 200

    private init() {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }

    func save(_ session: AgentSession) {
        let persisted = PersistedSession(
            id: session.id,
            agentType: session.agentType.rawValue,
            status: session.status.rawValue,
            title: session.title,
            workingOn: session.workingOn,
            startedAt: session.startedAt,
            lastUpdated: session.lastUpdated,
            toolCount: session.toolHistory.count,
            tokenUsage: session.tokenUsage.map {
                .init(inputTokens: $0.inputTokens, outputTokens: $0.outputTokens)
            },
            model: session.model,
            connectionType: session.connectionType.rawValue
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(persisted) else { return }

        let filename = "\(directory)/\(session.id).json"
        try? data.write(to: URL(fileURLWithPath: filename))
        pruneOldFiles()
    }

    func loadAll() -> [AgentSession] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.hasSuffix(".json") }
            .compactMap { file -> PersistedSession? in
                let path = "\(directory)/\(file)"
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
                return try? decoder.decode(PersistedSession.self, from: data)
            }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(50)
            .map { p in
                AgentSession(
                    id: p.id,
                    agentType: AgentType(rawValue: p.agentType) ?? .unknown,
                    status: AgentSessionStatus(rawValue: p.status) ?? .done,
                    title: p.title,
                    workingOn: p.workingOn,
                    startedAt: p.startedAt,
                    lastUpdated: p.lastUpdated,
                    tokenUsage: p.tokenUsage.map {
                        TokenUsage(inputTokens: $0.inputTokens, outputTokens: $0.outputTokens)
                    },
                    model: p.model
                )
            }
    }

    private func pruneOldFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return }
        let jsonFiles = files.filter { $0.hasSuffix(".json") }
        guard jsonFiles.count > maxFiles else { return }

        let sorted = jsonFiles
            .compactMap { file -> (String, Date)? in
                let path = "\(directory)/\(file)"
                guard let attrs = try? fm.attributesOfItem(atPath: path),
                      let date = attrs[.modificationDate] as? Date else { return nil }
                return (path, date)
            }
            .sorted { $0.1 < $1.1 }

        for (path, _) in sorted.prefix(sorted.count - maxFiles) {
            try? fm.removeItem(atPath: path)
        }
    }
}
