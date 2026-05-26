import SwiftUI

@MainActor
final class NotchConnectivityEventsHandler {
    private let notchViewModel: NotchViewModel
    private let bluetoothViewModel: BluetoothViewModel
    private let networkViewModel: NetworkViewModel
    private let settingsViewModel: SettingsViewModel
    private let buddyEngine: CatAnimationEngine

    init(
        notchViewModel: NotchViewModel,
        bluetoothViewModel: BluetoothViewModel,
        networkViewModel: NetworkViewModel,
        settingsViewModel: SettingsViewModel,
        buddyEngine: CatAnimationEngine
    ) {
        self.notchViewModel = notchViewModel
        self.bluetoothViewModel = bluetoothViewModel
        self.networkViewModel = networkViewModel
        self.settingsViewModel = settingsViewModel
        self.buddyEngine = buddyEngine
    }

    func handleBluetooth(_ event: BluetoothEvent) {
        switch event {
        case .connected:
            buddyEngine.showTemporaryScene(.bluetoothConnected, duration: 2.0)
            guard settingsViewModel.isTemporaryActivityEnabled(.bluetooth) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    BluetoothConnectedNotchContent(
                        bluetoothViewModel: bluetoothViewModel,
                        settings: settingsViewModel.connectivity,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .bluetooth)
                )
            )
        }
    }

    func handleNetwork(_ event: NetworkEvent) {
        switch event {
        case .wifiConnected:
            buddyEngine.showTemporaryScene(.wifiConnected, duration: 2.0)
            guard settingsViewModel.isTemporaryActivityEnabled(.wifi) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    WifiConnectedNotchContent(
                        networkViewModel: networkViewModel
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .wifi)
                )
            )

        case .vpnConnected:
            buddyEngine.showTemporaryScene(.vpnConnected, duration: 2.0)
            guard settingsViewModel.isTemporaryActivityEnabled(.vpn) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    VpnConnectedNotchContent(
                        networkViewModel: networkViewModel,
                        settings: settingsViewModel.connectivity
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .vpn)
                )
            )

        case .noInternetConnection:
            buddyEngine.showTemporaryScene(.wifiLost, duration: 3.0)
            guard settingsViewModel.connectivity.isNoInternetTemporaryActivityEnabled else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    NoInternetConnectionContent(
                        onDismiss: { [weak self] in
                            self?.notchViewModel.hideTemporaryNotification()
                        }
                    ),
                    duration: .infinity
                )
            )

        case .hotspotActive:
            buddyEngine.showTemporaryScene(.hotspotActive, duration: 2.5)
            guard settingsViewModel.isLiveActivityEnabled(.hotspot) else { return }
            notchViewModel.send(
                .showLiveActivity(
                    HotspotActiveContent(settingsViewModel: settingsViewModel)
                )
            )

        case .hotspotHide:
            notchViewModel.send(.hideLiveActivity(id: NotchContentRegistry.Network.hotspot.id))
        }
    }
}
