
import SwiftUI

@MainActor
final class NotchDownloadEventsHandler {
    private let notchViewModel: NotchViewModel
    private let downloadViewModel: DownloadViewModel
    private let settingsViewModel: SettingsViewModel
    private let buddyEngine: CatAnimationEngine

    init(
        notchViewModel: NotchViewModel,
        downloadViewModel: DownloadViewModel,
        settingsViewModel: SettingsViewModel,
        buddyEngine: CatAnimationEngine
    ) {
        self.notchViewModel = notchViewModel
        self.downloadViewModel = downloadViewModel
        self.settingsViewModel = settingsViewModel
        self.buddyEngine = buddyEngine
    }

    func handleDownload(_ event: DownloadEvent) {
        switch event {
        case .started:
            buddyEngine.showTemporaryScene(.downloading, duration: 3.0)
            guard settingsViewModel.isLiveActivityEnabled(.downloads) else { return }
            notchViewModel.send(
                .showLiveActivity(
                    DownloadNotchContent(
                        downloadViewModel: downloadViewModel,
                        settingsViewModel: settingsViewModel
                    )
                )
            )

        case .stopped:
            notchViewModel.send(.hideLiveActivity(id: NotchContentRegistry.Media.download.id))
        }
    }
}

