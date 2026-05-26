import SwiftUI

@MainActor
final class NotchPowerEventsHandler {
    private let notchViewModel: NotchViewModel
    private let powerService: PowerService
    private let settingsViewModel: SettingsViewModel
    private let buddyEngine: CatAnimationEngine

    init(
        notchViewModel: NotchViewModel,
        powerService: PowerService,
        settingsViewModel: SettingsViewModel,
        buddyEngine: CatAnimationEngine
    ) {
        self.notchViewModel = notchViewModel
        self.powerService = powerService
        self.settingsViewModel = settingsViewModel
        self.buddyEngine = buddyEngine
    }

    func handle(_ event: PowerEvent) {
        switch event {
        case .charger:
            buddyEngine.showTemporaryScene(.charging, duration: 2.5)
            guard settingsViewModel.isTemporaryActivityEnabled(.charger) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    ChargerNotchContent(
                        powerService: powerService,
                        settingsViewModel: settingsViewModel
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .charger)
                )
            )

        case .lowPower:
            buddyEngine.showTemporaryScene(.lowBattery, duration: 3.0)
            guard settingsViewModel.isTemporaryActivityEnabled(.lowPower) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    LowPowerNotchContent(
                        powerService: powerService,
                        settingsViewModel: settingsViewModel
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .lowPower)
                )
            )

        case .fullPower:
            buddyEngine.showTemporaryScene(.fullBattery, duration: 2.5)
            guard settingsViewModel.isTemporaryActivityEnabled(.fullPower) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    FullPowerNotchContent(
                        powerService: powerService,
                        settingsViewModel: settingsViewModel
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .fullPower)
                )
            )
        }
    }
}
