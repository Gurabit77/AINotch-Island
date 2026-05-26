
import CoreAudio

final class InactiveAudioOutputRoutingService: AudioOutputRouting {
    func availableRoutes() -> [AudioOutputRoute] { [] }

    func currentRoute() -> AudioOutputRoute? { nil }

    @discardableResult
    func setCurrentRoute(_ id: AudioDeviceID) -> Bool { false }
}
