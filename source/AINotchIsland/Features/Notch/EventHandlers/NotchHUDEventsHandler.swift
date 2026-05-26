import SwiftUI

@MainActor
final class NotchHUDEventsHandler {
    private let notchViewModel: NotchViewModel
    private let settingsViewModel: SettingsViewModel
    private let buddyEngine: CatAnimationEngine
    // HUD events fire on every keystroke of brightness/volume — debounce
    // buddy scene triggers so the cat doesn't flicker through 20 frames
    // when the user holds down a key.
    private var lastHudSceneAt: Date = .distantPast

    init(
        notchViewModel: NotchViewModel,
        settingsViewModel: SettingsViewModel,
        buddyEngine: CatAnimationEngine
    ) {
        self.notchViewModel = notchViewModel
        self.settingsViewModel = settingsViewModel
        self.buddyEngine = buddyEngine
    }

    private func playHudScene(_ scene: CrabScene) {
        let now = Date()
        guard now.timeIntervalSince(lastHudSceneAt) > 0.8 else { return }
        lastHudSceneAt = now
        buddyEngine.showTemporaryScene(scene, duration: 1.2)
    }

    func handleHud(_ event: HudEvent) {
        DebugLogWriter.shared.append("[HUD] handleHud fired: \(event)\n")
        switch event {
        case .display(let level):
            playHudScene(.brightnessChange)
            guard settingsViewModel.isHUDEnabled(.brightness) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    HudNotchContent(
                        kind: .brightness,
                        level: level,
                        style: settingsViewModel.hudStyle,
                        indicatorStyle: settingsViewModel.hudIndicatorStyle,
                        indicatorTintStyle: settingsViewModel.hudIndicatorTintStyle,
                        showsIndicatorGlow: settingsViewModel.isHUDIndicatorGlowEnabled,
                        usesColoredLevelStroke: settingsViewModel.isHUDColoredLevelStrokeEnabled,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .brightness)
                )
            )

        case .keyboard(let level):
            playHudScene(.brightnessChange)
            guard settingsViewModel.isHUDEnabled(.keyboard) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    HudNotchContent(
                        kind: .keyboard,
                        level: level,
                        style: settingsViewModel.hudStyle,
                        indicatorStyle: settingsViewModel.hudIndicatorStyle,
                        indicatorTintStyle: settingsViewModel.hudIndicatorTintStyle,
                        showsIndicatorGlow: settingsViewModel.isHUDIndicatorGlowEnabled,
                        usesColoredLevelStroke: settingsViewModel.isHUDColoredLevelStrokeEnabled,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .keyboard)
                )
            )

        case .volume(let level):
            playHudScene(level <= 0 ? .volumeMute : .volumeUp)
            guard settingsViewModel.isHUDEnabled(.volume) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    HudNotchContent(
                        kind: .volume,
                        level: level,
                        style: settingsViewModel.hudStyle,
                        indicatorStyle: settingsViewModel.hudIndicatorStyle,
                        indicatorTintStyle: settingsViewModel.hudIndicatorTintStyle,
                        showsIndicatorGlow: settingsViewModel.isHUDIndicatorGlowEnabled,
                        usesColoredLevelStroke: settingsViewModel.isHUDColoredLevelStrokeEnabled,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .volume)
                )
            )
        }
    }
}
