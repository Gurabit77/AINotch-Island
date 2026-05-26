import Cocoa
import SwiftUI

enum WindowsScene {
    static let settings = "settings"
}

@main
struct AINotchIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The status bar icon is owned by MenuBarStatusController (set up
        // in AgentHaloViewModel.startServices). It shows the live agent
        // count + global status color, and its popover surfaces both the
        // active sessions list AND the app-level menu (Settings, Check for
        // Updates, Restart, Quit). Having a second MenuBarExtra here would
        // produce a duplicate icon — they were merged in the popover.

        WindowGroup(id: WindowsScene.settings) {
            SettingsRootView(
                powerService: appDelegate.powerService,
                settingsViewModel: appDelegate.settingsViewModel,
                notchViewModel: appDelegate.notchViewModel,
                notchEventCoordinator: appDelegate.notchEventCoordinator,
                bluetoothViewModel: appDelegate.bluetoothViewModel,
                networkViewModel: appDelegate.networkViewModel,
                downloadViewModel: appDelegate.downloadViewModel,
                nowPlayingViewModel: appDelegate.nowPlayingViewModel,
                timerViewModel: appDelegate.timerViewModel,
                lockScreenManager: appDelegate.lockScreenManager,
                agentHaloViewModel: appDelegate.agentHaloViewModel,
                extensionManager: appDelegate.container.extensionManager
            )
            .background(.ultraThinMaterial)
            .settingsWindowBridge()
            .frame(width: SettingsWindowLayout.width, height: SettingsWindowLayout.height)
        }
        .defaultSize(width: SettingsWindowLayout.width, height: SettingsWindowLayout.height)
        .windowResizability(.contentSize)
    }
}
