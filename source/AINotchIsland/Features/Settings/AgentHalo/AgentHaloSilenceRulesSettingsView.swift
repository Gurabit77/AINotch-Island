import SwiftUI

struct AgentHaloSilenceRulesSettingsView: View {
    @StateObject private var store = SessionSilenceStore.shared
    @State private var newPattern = ""
    @State private var newKind: SessionSilenceRule.Kind = .directory

    var body: some View {
        Form {
            Section(L10n.appKey("settings.agentHalo.silence.activeRules", fallback: "Active Rules")) {
                if store.rules.isEmpty {
                    Text(L10n.app("settings.agentHalo.silence.noRules", fallback: "No silence rules configured"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(store.rules) { rule in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { rule.enabled },
                                set: { _ in store.toggle(id: rule.id) }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.pattern)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    Text(rule.kind == .directory ? L10n.app("settings.agentHalo.silence.directoryMatch", fallback: "Directory match") : L10n.app("settings.agentHalo.silence.promptPrefixMatch", fallback: "Prompt prefix match"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                store.remove(id: rule.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section(L10n.appKey("settings.agentHalo.silence.addRule", fallback: "Add Rule")) {
                Picker(L10n.appKey("settings.agentHalo.silence.type", fallback: "Type"), selection: $newKind) {
                    Text(L10n.app("settings.agentHalo.silence.directory", fallback: "Directory")).tag(SessionSilenceRule.Kind.directory)
                    Text(L10n.app("settings.agentHalo.silence.promptPrefix", fallback: "Prompt Prefix")).tag(SessionSilenceRule.Kind.promptPrefix)
                }
                .pickerStyle(.segmented)

                TextField(
                    newKind == .directory ? "e.g., /memory-agent" : "e.g., background-task",
                    text: $newPattern
                )
                .textFieldStyle(.roundedBorder)

                Button(L10n.app("settings.agentHalo.silence.addRuleButton", fallback: "Add Rule")) {
                    guard !newPattern.isEmpty else { return }
                    store.add(SessionSilenceRule(kind: newKind, pattern: newPattern))
                    newPattern = ""
                }
                .disabled(newPattern.isEmpty)
            }

            Section {
                Text(L10n.app("settings.agentHalo.silence.description", fallback: "Silenced sessions are hidden from the notch UI but continue running normally. Rules match against session working directory or task description prefix."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
