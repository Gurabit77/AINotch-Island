import SwiftUI

struct AgentHaloAppearanceSettingsView: View {
    @ObservedObject var settings: ApplicationSettingsStore

    var body: some View {
        Form {
            Section(L10n.app("settings.agentHalo.appearance.layoutMode", fallback: "Layout Mode")) {
                Picker(L10n.app("settings.agentHalo.appearance.compactLayout", fallback: "Compact Layout"), selection: $settings.agentHaloLayoutMode) {
                    ForEach(AgentHaloLayoutMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(L10n.app("settings.agentHalo.appearance.preview", fallback: "Preview")) {
                compactPreview
            }
        }
        .formStyle(.grouped)
    }

    private var compactPreview: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black)
                .frame(height: 44)
                .overlay {
                    HStack(spacing: 6) {
                        Circle()
                            .stroke(.green, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.green)
                            }
                        HStack(spacing: 3) {
                            Circle().fill(.green).frame(width: 5, height: 5)
                            Circle().fill(.orange).frame(width: 4, height: 4)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
            if settings.agentHaloLayoutMode == .detailed {
                Text("Claude Code · Implementing feature... 2m")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.quaternary))
            }
        }
        .padding(.vertical, 4)
    }
}
