import SwiftUI
import Combine

struct AgentHaloSoundsSettingsView: View {
    @StateObject private var soundManager = SoundManagerSettingsAdapter()

    var body: some View {
        Form {
            Section(L10n.appKey("settings.agentHalo.sounds.general", fallback: "General")) {
                Toggle(L10n.appKey("settings.agentHalo.sounds.enableSounds", fallback: "Enable Sounds"), isOn: $soundManager.isEnabled)
                if soundManager.isEnabled {
                    Slider(value: $soundManager.volume, in: 0...1) {
                        Text(L10n.app("settings.agentHalo.sounds.volume", fallback: "Volume"))
                    }
                    Picker(L10n.appKey("settings.agentHalo.sounds.theme", fallback: "Theme"), selection: $soundManager.theme) {
                        Text(L10n.app("settings.agentHalo.sounds.system", fallback: "System")).tag(SoundTheme.system)
                        Text(L10n.app("settings.agentHalo.sounds.minimal", fallback: "Minimal")).tag(SoundTheme.minimal)
                        Text(L10n.app("settings.agentHalo.sounds.retro", fallback: "Retro")).tag(SoundTheme.retro)
                    }
                }
            }

            if soundManager.isEnabled {
                Section(L10n.appKey("settings.agentHalo.sounds.events", fallback: "Events")) {
                    ForEach(SoundEvent.allCases, id: \.self) { event in
                        HStack {
                            Toggle(event.displayName, isOn: soundManager.binding(for: event))
                            Spacer()
                            Button {
                                SoundManager.shared.play(event)
                            } label: {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(L10n.appKey("settings.agentHalo.sounds.quietHours", fallback: "Quiet Hours")) {
                    Toggle(L10n.appKey("settings.agentHalo.sounds.enableQuietHours", fallback: "Enable Quiet Hours"), isOn: $soundManager.quietHoursEnabled)
                    if soundManager.quietHoursEnabled {
                        HStack {
                            Stepper("\(L10n.app("settings.agentHalo.sounds.start", fallback: "Start")): \(soundManager.quietHoursStart):00", value: $soundManager.quietHoursStart, in: 0...23)
                            Stepper("\(L10n.app("settings.agentHalo.sounds.end", fallback: "End")): \(soundManager.quietHoursEnd):00", value: $soundManager.quietHoursEnd, in: 0...23)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

@MainActor
final class SoundManagerSettingsAdapter: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { SoundManager.shared.isEnabled = isEnabled }
    }
    @Published var volume: Double {
        didSet { SoundManager.shared.volume = volume }
    }
    @Published var theme: SoundTheme {
        didSet { SoundManager.shared.theme = theme }
    }
    @Published var quietHoursEnabled: Bool {
        didSet { SoundManager.shared.quietHoursEnabled = quietHoursEnabled }
    }
    @Published var quietHoursStart: Int {
        didSet { SoundManager.shared.quietHoursStart = quietHoursStart }
    }
    @Published var quietHoursEnd: Int {
        didSet { SoundManager.shared.quietHoursEnd = quietHoursEnd }
    }
    @Published var disabledEvents: Set<SoundEvent> {
        didSet { SoundManager.shared.disabledEvents = disabledEvents }
    }

    init() {
        let sm = SoundManager.shared
        self.isEnabled = sm.isEnabled
        self.volume = sm.volume
        self.theme = sm.theme
        self.quietHoursEnabled = sm.quietHoursEnabled
        self.quietHoursStart = sm.quietHoursStart
        self.quietHoursEnd = sm.quietHoursEnd
        self.disabledEvents = sm.disabledEvents
    }

    func binding(for event: SoundEvent) -> Binding<Bool> {
        Binding<Bool>(
            get: { !self.disabledEvents.contains(event) },
            set: { enabled in
                if enabled {
                    self.disabledEvents.remove(event)
                } else {
                    self.disabledEvents.insert(event)
                }
            }
        )
    }
}
