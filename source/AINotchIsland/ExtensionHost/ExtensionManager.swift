import SwiftUI
import Combine
import os.log

@MainActor
final class ExtensionManager: ObservableObject {
    @Published var loadedExtensions: [LoadedExtension] = []
    @Published var activeRuntimes: [String: ExtensionJSRuntime] = [:]
    @Published var extensionViews: [String: ViewNode] = [:]

    private let agentState: AgentHaloState
    private var refreshTimer: AnyCancellable?

    private var extensionsDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".agent-halo/extensions")
    }

    private var bundledExtensionsDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Extensions")
    }

    init(agentState: AgentHaloState) {
        self.agentState = agentState
    }

    func start() {
        createDirectoryIfNeeded()
        installBuiltinExtensions()
        discoverExtensions()
        activateAutoStartExtensions()
        restorePreviouslyActiveExtensions()
        startRefreshTimer()
    }

    func stop() {
        refreshTimer?.cancel()
        activeRuntimes.values.forEach { $0.callDeactivate() }
        activeRuntimes.removeAll()
    }

    func activateExtension(id: String) {
        guard let ext = loadedExtensions.first(where: { $0.id == id }) else { return }
        guard activeRuntimes[id] == nil else { return }

        let runtime = ExtensionJSRuntime(extensionId: id, agentState: agentState)
        runtime.onViewUpdate { [weak self] node in
            self?.extensionViews[id] = node
        }

        let entryURL = ext.bundlePath.appendingPathComponent(ext.manifest.entry)
        do {
            try runtime.loadScript(at: entryURL)
            runtime.callActivate()
            activeRuntimes[id] = runtime

            if let idx = loadedExtensions.firstIndex(where: { $0.id == id }) {
                loadedExtensions[idx].isActive = true
            }

            if let node = runtime.callRender() {
                extensionViews[id] = node
            }
            persistActiveExtensions()
        } catch {
            AppLogger.extensions.error("Failed to load \(id): \(error)")
        }
    }

    func deactivateExtension(id: String) {
        activeRuntimes[id]?.callDeactivate()
        activeRuntimes.removeValue(forKey: id)
        extensionViews.removeValue(forKey: id)

        if let idx = loadedExtensions.firstIndex(where: { $0.id == id }) {
            loadedExtensions[idx].isActive = false
        }
        persistActiveExtensions()
    }

    func refreshActiveViews() {
        for (id, runtime) in activeRuntimes {
            if let node = runtime.callRender() {
                extensionViews[id] = node
            }
        }
    }

    func notifyExtensions(event: String, data: [String: Any] = [:]) {
        for (_, runtime) in activeRuntimes {
            runtime.emitEvent(event, data: data)
        }
    }

    private func activateAutoStartExtensions() {
        for ext in loadedExtensions where ext.manifest.autoActivate == true {
            if activeRuntimes[ext.id] == nil {
                activateExtension(id: ext.id)
            }
        }
    }

    private func restorePreviouslyActiveExtensions() {
        let activeIds = UserDefaults.standard.stringArray(forKey: "activeExtensions") ?? []
        for id in activeIds where activeRuntimes[id] == nil {
            activateExtension(id: id)
        }
    }

    private func persistActiveExtensions() {
        let ids = Array(activeRuntimes.keys)
        UserDefaults.standard.set(ids, forKey: "activeExtensions")
    }

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: extensionsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func installBuiltinExtensions() {
        let builtins: [(id: String, manifest: String, script: String)] = [
            (
                id: "agents-status",
                manifest: Self.agentsStatusManifest,
                script: Self.agentsStatusScript
            )
        ]

        for builtin in builtins {
            let dir = extensionsDirectory.appendingPathComponent(builtin.id)
            let manifestURL = dir.appendingPathComponent("manifest.json")
            if FileManager.default.fileExists(atPath: manifestURL.path) { continue }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? builtin.manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
            let scriptURL = dir.appendingPathComponent("index.js")
            try? builtin.script.write(to: scriptURL, atomically: true, encoding: .utf8)
        }
    }

    private static let agentsStatusManifest = """
    {"id":"com.agenthalo.agents-status","name":"Agents Status","version":"1.0.0","description":"Shows active AI agents status","author":"AINotchIsland","entry":"index.js","icon":"circle.hexagongrid.fill","permissions":["agents"],"autoActivate":true,"notchConfig":{"compactWidth":100,"expandedWidth":280,"expandedHeight":240,"expandable":true,"strokeColor":"green"}}
    """

    private static let agentsStatusScript = """
    var blinkState = false;
    function activate() { setInterval(function() { blinkState = !blinkState; }, 1000); }
    function deactivate() {}
    function render() {
        var agents = AgentHalo.agents.getAgents();
        var status = AgentHalo.agents.getStatus();
        var count = AgentHalo.agents.getActiveCount();
        if (count === 0) {
            return UI.hstack([
                UI.image("circle.hexagongrid", {style:{fontSize:10,foregroundColor:"gray",opacity:0.5}}),
                UI.text("No agents", {fontSize:10,foregroundColor:"gray",opacity:0.6})
            ], {spacing:4});
        }
        var statusColor = "green";
        var statusIcon = "circle.fill";
        if (status === "waiting") { statusColor = "orange"; statusIcon = "exclamationmark.circle.fill"; }
        if (status === "error") { statusColor = "red"; statusIcon = "xmark.circle.fill"; }
        var items = [
            UI.image(statusIcon, {style:{fontSize:8,foregroundColor:statusColor}}),
            UI.text(count + " agent" + (count > 1 ? "s" : ""), {fontSize:11,fontWeight:"medium",foregroundColor:"white"})
        ];
        if (status === "waiting" && blinkState) {
            items.push(UI.text("!", {fontSize:10,fontWeight:"bold",foregroundColor:"orange"}));
        }
        return UI.hstack(items, {spacing:5});
    }
    """

    private func discoverExtensions() {
        var discovered: [LoadedExtension] = []

        discovered.append(contentsOf: scanDirectory(extensionsDirectory))

        if let bundled = bundledExtensionsDirectory {
            discovered.append(contentsOf: scanDirectory(bundled))
        }

        discovered.append(contentsOf: scanDirectory(
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/Extensions")
        ))

        loadedExtensions = discovered
    }

    private func scanDirectory(_ dir: URL) -> [LoadedExtension] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return contents.compactMap { folder in
            let manifestURL = folder.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data) else {
                return nil
            }
            return LoadedExtension(id: manifest.id, manifest: manifest, bundlePath: folder)
        }
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshActiveViews()
            }
    }
}
