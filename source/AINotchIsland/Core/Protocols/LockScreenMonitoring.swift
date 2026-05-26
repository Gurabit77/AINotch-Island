
import Foundation

protocol LockScreenMonitoring: AnyObject {
    var onLockStateChange: ((Bool) -> Void)? { get set }

    func startMonitoring()
    func stopMonitoring()
}
