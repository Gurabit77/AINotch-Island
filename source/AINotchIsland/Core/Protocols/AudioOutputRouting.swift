
import Foundation
import CoreAudio

protocol AudioOutputRouting: AnyObject {
    func availableRoutes() -> [AudioOutputRoute]
    func currentRoute() -> AudioOutputRoute?
    @discardableResult func setCurrentRoute(_ id: AudioDeviceID) -> Bool
}
