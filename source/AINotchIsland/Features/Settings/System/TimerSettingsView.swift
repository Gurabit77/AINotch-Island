import SwiftUI

struct TimerSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore

    private var isDefaultStrokeLocked: Bool {
        appearanceSettings.isDefaultActivityStrokeEnabled
    }

    var body: some View {
        SettingsPageScrollView {
            timerActivity
        }
    }

    private var timerActivity: some View {
        SettingsCard(title: L10n.appKey("settings.timer.activity", fallback: "Timer activity")) {
            SettingsToggleRow(
                title: L10n.appKey("settings.timer.liveActivity.title", fallback: "Timer live activity"),
                description: L10n.appKey("settings.timer.liveActivity.description", fallback: "Show the active Clock timer in the notch."),
                systemImage: "timer",
                color: .orange,
                isOn: $mediaSettings.isTimerLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.timer"
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            SettingsStrokeToggleRow(
                title: L10n.appKey("settings.timer.defaultStroke.title", fallback: "Default stroke"),
                description: L10n.appKey("settings.timer.defaultStroke.description", fallback: "Use the standard white notch stroke instead of the orange timer stroke."),
                isOn: $mediaSettings.isTimerDefaultStrokeEnabled,
                accessibilityIdentifier: "settings.activities.live.timer.defaultStroke"
            )
            .disabled(isDefaultStrokeLocked)
            .opacity(isDefaultStrokeLocked ? 0.5 : 1)
        }
    }
}
