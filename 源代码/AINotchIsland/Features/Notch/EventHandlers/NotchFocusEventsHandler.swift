import SwiftUI

@MainActor
final class NotchFocusEventsHandler {
    private let notchViewModel: NotchViewModel
    private let settingsViewModel: SettingsViewModel
    private let buddyEngine: CatAnimationEngine

    init(
        notchViewModel: NotchViewModel,
        settingsViewModel: SettingsViewModel,
        buddyEngine: CatAnimationEngine
    ) {
        self.notchViewModel = notchViewModel
        self.settingsViewModel = settingsViewModel
        self.buddyEngine = buddyEngine
    }

    func handleFocus(_ event: FocusEvent) {
        switch event {
        case .FocusOn:
            buddyEngine.showTemporaryScene(.focusOn, duration: 2.5)
            guard settingsViewModel.isLiveActivityEnabled(.focus) else { return }
            notchViewModel.send(.showLiveActivity(FocusOnNotchContent(settingsViewModel: settingsViewModel)))

        case .FocusOff:
            buddyEngine.showTemporaryScene(.focusOff, duration: 2.0)
            notchViewModel.send(.hideLiveActivity(id: NotchContentRegistry.Focus.active.id))
            guard settingsViewModel.isTemporaryActivityEnabled(.focusOff) else { return }
            notchViewModel.send(.showTemporaryNotification(FocusOffNotchContent(settingsViewModel: settingsViewModel), duration: settingsViewModel.temporaryActivityDuration(for: .focusOff))
            )
        }
    }
}
