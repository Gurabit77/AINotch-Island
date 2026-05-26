import SwiftUI

struct AgentHaloBehaviorSettingsView: View {
    @ObservedObject var settings: ApplicationSettingsStore

    private var idleTimeoutOptions: [(String, Int)] {
        [
            (L10n.app("settings.agentHalo.behavior.never", fallback: "Never"), 0),
            (L10n.app("settings.agentHalo.behavior.30minutes", fallback: "30 minutes"), 1800),
            (L10n.app("settings.agentHalo.behavior.1hour", fallback: "1 hour"), 3600),
            (L10n.app("settings.agentHalo.behavior.2hours", fallback: "2 hours"), 7200),
            (L10n.app("settings.agentHalo.behavior.4hours", fallback: "4 hours"), 14400),
            (L10n.app("settings.agentHalo.behavior.8hours", fallback: "8 hours"), 28800),
            (L10n.app("settings.agentHalo.behavior.24hours", fallback: "24 hours"), 86400),
        ]
    }

    var body: some View {
        Form {
            Section(L10n.appKey("settings.agentHalo.behavior.smartSuppression", fallback: "Smart Suppression")) {
                Toggle(L10n.appKey("settings.agentHalo.behavior.suppressAutoExpand", fallback: "Suppress auto-expand when terminal is focused"), isOn: $settings.agentHaloSmartSuppressionEnabled)
                Text(L10n.app("settings.agentHalo.behavior.suppressAutoExpandDescription", fallback: "When the agent's terminal is the frontmost window, the notch won't auto-expand on hover."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.appKey("settings.agentHalo.behavior.autoApproval", fallback: "Auto Approval")) {
                Toggle(L10n.appKey("settings.agentHalo.behavior.autoMode", fallback: "Auto Mode"), isOn: $settings.agentHaloAutoMode)
                Text(L10n.app("settings.agentHalo.behavior.autoModeDescription", fallback: "Automatically approve low and medium risk actions. High-risk actions still require manual approval."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.appKey("settings.agentHalo.behavior.bypassPermissions", fallback: "Bypass All Permissions"), isOn: $settings.agentHaloBypassPermissions)
                if settings.agentHaloBypassPermissions {
                    Label(L10n.appKey("settings.agentHalo.behavior.bypassWarning", fallback: "All actions are auto-approved — no safety prompts will be shown."), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(L10n.appKey("settings.agentHalo.behavior.idleCleanup", fallback: "Idle Cleanup")) {
                Picker(L10n.appKey("settings.agentHalo.behavior.archiveAfter", fallback: "Archive idle sessions after"), selection: $settings.agentHaloIdleCleanupTimeout) {
                    ForEach(idleTimeoutOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                Text(L10n.app("settings.agentHalo.behavior.archiveDescription", fallback: "Sessions with no activity will be automatically archived after this duration."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
