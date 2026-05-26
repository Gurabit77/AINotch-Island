import Foundation

enum HookSupport: String, Codable {
    case full
    case partial
    case basic
    case none
}

struct AgentRegistryEntry: Codable {
    let name: String
    let source: String
    let agentType: String
    var processPatterns: [String]
    var bundleIdentifiers: [String]
    var appNamePrefixes: [String]
    var port: UInt16?
    var pidFile: String?
    var hookSupport: HookSupport
    var icon: String
    var configPaths: [String]

    enum CodingKeys: String, CodingKey {
        case name, source, agentType, processPatterns, bundleIdentifiers
        case appNamePrefixes, port, pidFile, hookSupport, icon, configPaths
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        source = try c.decode(String.self, forKey: .source)
        agentType = try c.decode(String.self, forKey: .agentType)
        processPatterns = try c.decodeIfPresent([String].self, forKey: .processPatterns) ?? []
        bundleIdentifiers = try c.decodeIfPresent([String].self, forKey: .bundleIdentifiers) ?? []
        appNamePrefixes = try c.decodeIfPresent([String].self, forKey: .appNamePrefixes) ?? []
        port = try c.decodeIfPresent(UInt16.self, forKey: .port)
        pidFile = try c.decodeIfPresent(String.self, forKey: .pidFile)
        hookSupport = try c.decodeIfPresent(HookSupport.self, forKey: .hookSupport) ?? .none
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "cpu"
        configPaths = try c.decodeIfPresent([String].self, forKey: .configPaths) ?? []
    }

    var resolvedPidFile: String? {
        pidFile?.replacingOccurrences(of: "~", with: NSHomeDirectory())
    }

    var resolvedConfigPaths: [String] {
        configPaths.map { $0.replacingOccurrences(of: "~", with: NSHomeDirectory()) }
    }

    func toDefinition() -> AgentDefinition {
        AgentDefinition(
            name: name,
            source: source,
            agentType: AgentType(rawValue: agentType) ?? .unknown,
            processPatterns: processPatterns,
            bundleIdentifiers: bundleIdentifiers,
            appNamePrefixes: appNamePrefixes,
            port: port,
            pidFile: resolvedPidFile,
            hookSupport: hookSupport,
            configPaths: resolvedConfigPaths
        )
    }
}

final class AgentRegistry {
    static let shared = AgentRegistry()

    private(set) var entries: [AgentRegistryEntry] = []
    private(set) var allDefinitions: [AgentDefinition] = []

    private let userRegistryPath = NSHomeDirectory() + "/.agent-halo/agents.json"

    private init() {
        reload()
    }

    func reload() {
        var combined: [AgentRegistryEntry] = []

        if let builtIn = loadBuiltinRegistry() {
            combined.append(contentsOf: builtIn)
        }

        if let userDefined = loadUserRegistry() {
            for entry in userDefined {
                if let idx = combined.firstIndex(where: { $0.source == entry.source }) {
                    combined[idx] = entry
                } else {
                    combined.append(entry)
                }
            }
        }

        entries = combined
        allDefinitions = combined.map { $0.toDefinition() }
    }

    private func loadBuiltinRegistry() -> [AgentRegistryEntry]? {
        guard let url = Bundle.main.url(forResource: "agents-builtin", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode([AgentRegistryEntry].self, from: data)
    }

    private func loadUserRegistry() -> [AgentRegistryEntry]? {
        let url = URL(fileURLWithPath: userRegistryPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([AgentRegistryEntry].self, from: data)
    }
}
