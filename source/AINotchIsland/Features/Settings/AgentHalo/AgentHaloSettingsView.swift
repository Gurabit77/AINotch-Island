import SwiftUI
import Combine

struct AgentHaloSettingsView: View {
    @ObservedObject var viewModel: AgentHaloViewModel
    @ObservedObject var extensionManager: ExtensionManager
    @StateObject private var customAgentEditor = CustomAgentEditorState()

    var body: some View {
        SettingsPageScrollView {
            connectionCard
            agentManagementCard
            customAgentCard
            extensionsCard
            terminalCard
        }
    }

    private var connectionCard: some View {
        SettingsCard(title: L10n.appKey("settings.agentHalo.connectionHooks", fallback: "Connection & Hooks")) {
            ConnectionStatusView(
                socketServer: viewModel.socketServer,
                hookInstaller: viewModel.hookInstaller
            )

            Divider().opacity(0.6).padding(.vertical, 4)

            HStack(spacing: 8) {
                Button(L10n.app("settings.agentHalo.installAllHooks", fallback: "Install All Hooks")) {
                    viewModel.hookInstaller.installAll()
                }
                .controlSize(.small)

                Button(L10n.app("settings.agentHalo.uninstallAll", fallback: "Uninstall All")) {
                    viewModel.hookInstaller.uninstallAll()
                }
                .controlSize(.small)
            }

            Text(L10n.app("settings.agentHalo.hooksDescription", fallback: "Hooks are optional. Scanner detects all agents without hooks. Install hooks for richer tool history and token stats."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var agentManagementCard: some View {
        SettingsCard(title: L10n.appKey("settings.agentHalo.agentManagement", fallback: "Agent Management")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.app("settings.agentHalo.autoDetectedAgents", fallback: "Auto-detected Agents"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(viewModel.state.sessions.count) \(L10n.app("settings.agentHalo.found", fallback: "found"))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if viewModel.state.sessions.isEmpty {
                    Text(L10n.app("settings.agentHalo.noAgents", fallback: "No agents currently running. Start a CLI agent to see it here."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.state.sessions) { session in
                        AgentSettingsRow(session: session)
                    }
                }
            }

            Divider()
                .opacity(0.6)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.app("settings.agentHalo.scanning", fallback: "Scanning"))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(L10n.app("settings.agentHalo.active", fallback: "Active"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(L10n.app("settings.agentHalo.scanningDescription", fallback: "Agent Halo scans for running AI agents every 5 seconds using process detection, port scanning, and PID files."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var extensionsCard: some View {
        SettingsCard(title: L10n.appKey("settings.agentHalo.extensions", fallback: "Extensions")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.app("settings.agentHalo.installedExtensions", fallback: "Installed Extensions"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(extensionManager.loadedExtensions.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if extensionManager.loadedExtensions.isEmpty {
                    Text(L10n.app("settings.agentHalo.noExtensions", fallback: "No extensions installed. Place extensions in ~/.agent-halo/extensions/"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(extensionManager.loadedExtensions) { ext in
                        ExtensionSettingsRow(
                            ext: ext,
                            isActive: extensionManager.activeRuntimes[ext.id] != nil,
                            onToggle: { active in
                                if active {
                                    extensionManager.activateExtension(id: ext.id)
                                } else {
                                    extensionManager.deactivateExtension(id: ext.id)
                                }
                            }
                        )
                    }
                }
            }

            Divider()
                .opacity(0.6)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.app("settings.agentHalo.extensionDirectory", fallback: "Extension Directory"))
                    .font(.system(size: 12, weight: .medium))
                Text("~/.agent-halo/extensions/")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var terminalCard: some View {
        SettingsCard(title: L10n.appKey("settings.agentHalo.terminalJump", fallback: "Terminal Jump")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.app("settings.agentHalo.terminalJumpDescription", fallback: "Click an agent session to jump to its terminal window."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.app("settings.agentHalo.supportedTerminals", fallback: "Supported Terminals"))
                        .font(.system(size: 12, weight: .medium))
                    HStack(spacing: 12) {
                        ForEach(["iTerm2", "Terminal", "VS Code", "Cursor", "Warp", "Ghostty"], id: \.self) { name in
                            Text(name)
                                .font(.system(size: 10, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var customAgentCard: some View {
        SettingsCard(title: L10n.appKey("settings.agentHalo.customAgents", fallback: "Custom Agents")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.app("settings.agentHalo.userDefinedAgents", fallback: "User-defined Agents"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("~/.agent-halo/agents.json")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                ForEach(customAgentEditor.entries, id: \.name) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 12))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.name)
                                .font(.system(size: 11, weight: .medium))
                            Text(entry.processPatterns.joined(separator: ", "))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            customAgentEditor.remove(entry)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }

                Divider().opacity(0.6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.app("settings.agentHalo.addCustomAgent", fallback: "Add Custom Agent"))
                        .font(.system(size: 12, weight: .medium))

                    TextField(L10n.app("settings.agentHalo.name", fallback: "Name"), text: $customAgentEditor.newName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    TextField(L10n.app("settings.agentHalo.processPattern", fallback: "Process pattern (e.g. my-agent)"), text: $customAgentEditor.newProcess)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    HStack {
                        TextField(L10n.app("settings.agentHalo.portOptional", fallback: "Port (optional)"), text: $customAgentEditor.newPort)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .frame(width: 100)

                        Picker("Icon", selection: $customAgentEditor.newIcon) {
                            ForEach(["cpu", "terminal", "brain", "bolt.fill", "sparkles", "ant.fill", "wrench.and.screwdriver"], id: \.self) { icon in
                                Label(icon, systemImage: icon).tag(icon)
                            }
                        }
                        .frame(width: 140)

                        Spacer()

                        Button(L10n.app("settings.agentHalo.add", fallback: "Add")) {
                            customAgentEditor.addNew()
                        }
                        .disabled(customAgentEditor.newName.isEmpty || customAgentEditor.newProcess.isEmpty)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct AgentSettingsRow: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: session.agentType.icon)
                .font(.system(size: 14))
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 12, weight: .medium))
                if let workingOn = session.workingOn {
                    Text(workingOn)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.status.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case .working: return .green
        case .waitingApproval: return .orange
        case .error: return .red
        case .starting, .completing: return .blue
        default: return .gray
        }
    }
}

private struct ExtensionSettingsRow: View {
    let ext: LoadedExtension
    let isActive: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ext.manifest.icon ?? "puzzlepiece.extension")
                .font(.system(size: 14))
                .foregroundStyle(isActive ? .green : .gray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(ext.manifest.name)
                    .font(.system(size: 12, weight: .medium))
                Text("v\(ext.manifest.version) · \(ext.manifest.description)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isActive },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Agent Editor State

@MainActor
final class CustomAgentEditorState: ObservableObject {
    @Published var entries: [AgentRegistryEntry] = []
    @Published var newName = ""
    @Published var newProcess = ""
    @Published var newPort = ""
    @Published var newIcon = "cpu"

    private let filePath = NSHomeDirectory() + "/.agent-halo/agents.json"

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let decoded = try? JSONDecoder().decode([AgentRegistryEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    func addNew() {
        guard !newName.isEmpty, !newProcess.isEmpty else { return }
        let entry = AgentRegistryEntry(
            name: newName,
            source: newName.lowercased().replacingOccurrences(of: " ", with: "-"),
            agentType: "unknown",
            processPatterns: [newProcess],
            port: UInt16(newPort),
            hookSupport: .none,
            icon: newIcon
        )
        entries.append(entry)
        save()
        newName = ""
        newProcess = ""
        newPort = ""
        newIcon = "cpu"
        AgentRegistry.shared.reload()
    }

    func remove(_ entry: AgentRegistryEntry) {
        entries.removeAll { $0.name == entry.name }
        save()
        AgentRegistry.shared.reload()
    }

    private func save() {
        let dir = (filePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: URL(fileURLWithPath: filePath))
    }
}

extension AgentRegistryEntry {
    init(name: String, source: String, agentType: String, processPatterns: [String], port: UInt16?, hookSupport: HookSupport, icon: String) {
        self.name = name
        self.source = source
        self.agentType = agentType
        self.processPatterns = processPatterns
        self.bundleIdentifiers = []
        self.appNamePrefixes = []
        self.port = port
        self.pidFile = nil
        self.hookSupport = hookSupport
        self.icon = icon
        self.configPaths = []
    }
}
