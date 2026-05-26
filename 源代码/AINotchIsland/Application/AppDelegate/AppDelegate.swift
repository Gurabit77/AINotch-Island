
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let isRunningUITests: Bool
    let container: AppContainer

    var powerService: PowerService { container.powerService }
    var bluetoothViewModel: BluetoothViewModel { container.bluetoothViewModel }
    var powerViewModel: PowerViewModel { container.powerViewModel }
    var networkViewModel: NetworkViewModel { container.networkViewModel }
    var downloadViewModel: DownloadViewModel { container.downloadViewModel }
    var focusViewModel: FocusViewModel { container.focusViewModel }
    var settingsViewModel: SettingsViewModel { container.settingsViewModel }
    var nowPlayingViewModel: NowPlayingViewModel { container.nowPlayingViewModel }
    var timerViewModel: TimerViewModel { container.timerViewModel }
    var screenRecordingViewModel: ScreenRecordingViewModel { container.screenRecordingViewModel }
    var airDropViewModel: AirDropNotchViewModel { container.airDropViewModel }
    var lockScreenManager: LockScreenManager { container.lockScreenManager }
    var hardwareHUDMonitor: HardwareHUDMonitor { container.hardwareHUDMonitor }
    var notchViewModel: NotchViewModel { container.notchViewModel }
    var agentHaloViewModel: AgentHaloViewModel { container.agentHaloViewModel }
    var externalDriveMonitor: ExternalDriveMonitor { container.externalDriveMonitor }
    var screenshotMonitor: ScreenshotMonitor { container.screenshotMonitor }
    var externalDisplayMonitor: ExternalDisplayMonitor { container.externalDisplayMonitor }
    var airDropController: NotchAirDropController { container.airDropController }
    var notchEventCoordinator: NotchEventCoordinator { container.notchEventCoordinator }
    var lockScreenPanelManager: LockScreenPanelManager { container.lockScreenPanelManager }
    var lockScreenLiveActivityWindowManager: LockScreenLiveActivityWindowManager {
        container.lockScreenLiveActivityWindowManager
    }
    
    var window: OverlayPanelWindow!
    var localClickMonitor: Any?
    var localHoverMonitor: Any?
    var globalHoverMonitor: Any?
    var hoverCollapseWorkItem: DispatchWorkItem?
    let globalClickMonitor = GlobalClickMonitor()
    var cancellables = Set<AnyCancellable>()
    var isPrimaryWindowSuspendedForLock = false
    
    override init() {
        let isRunningUITests = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        self.isRunningUITests = isRunningUITests
        // Default first-launch flags. Registering the value here (instead
        // of writing to UserDefaults) means: if the user has never set
        // it, treat it as if they have already seen the onboarding —
        // skipping a 4-step intro that, in practice, traps new users
        // who quit the app before reaching the final "Finish" step. Any
        // explicit value the user has set is preserved.
        UserDefaults.standard.register(defaults: [
            "hasSeenOnboarding": true
        ])
        self.container = AppContainer(isRunningUITests: isRunningUITests)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy(
            showsDockIcon: isRunningUITests || settingsViewModel.application.isDockIconVisible
        )
        observeDisplayLocationChanges()
        observeFullscreenVisibilityChanges()
        observeDockIconVisibilityChanges()
        observeHUDConfigurationChanges()
        observeFeatureMonitoringChanges()
        observeLockScreenWindowHandoff()

        if !isRunningUITests {
            createNotchWindow()
            observeOutsideClickDismissal()
            _ = lockScreenPanelManager
            _ = lockScreenLiveActivityWindowManager
            hardwareHUDMonitor.startMonitoring()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateWindowFrame),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
            observeWorkspaceChanges()

            DispatchQueue.main.async {
                for w in NSApp.windows {
                    if w !== self.window {
                        w.orderOut(nil)
                    }
                }
            }
        }

        if !isRunningUITests {
            notchEventCoordinator.checkFirstLaunch()
        }

        lockScreenManager.startMonitoring()
        agentHaloViewModel.startServices()
        container.extensionManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        lockScreenManager.stopMonitoring()
        nowPlayingViewModel.stopMonitoring()
        downloadViewModel.stopMonitoring()
        timerViewModel.stopMonitoring()
        screenRecordingViewModel.stopMonitoring()
        hardwareHUDMonitor.stopMonitoring()
        agentHaloViewModel.stopServices()
        container.extensionManager.stop()
        if !isRunningUITests {
            lockScreenPanelManager.invalidate()
            lockScreenLiveActivityWindowManager.invalidate()
        }
        stopOutsideClickMonitoring()
    }

    func applyActivationPolicy(showsDockIcon: Bool) {
        let targetPolicy: NSApplication.ActivationPolicy = showsDockIcon ? .regular : .accessory

        guard NSApp.activationPolicy() != targetPolicy else { return }

        NSApp.setActivationPolicy(targetPolicy)

        if showsDockIcon {
            NSApp.activate(ignoringOtherApps: false)
        }
    }
}
