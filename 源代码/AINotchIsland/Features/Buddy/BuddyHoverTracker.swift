import Foundation
import Combine
internal import AppKit

enum BuddyLookDirection {
    case none, left, right, center
}

enum BuddyProximityLevel {
    case far, near, over
}

@MainActor
final class BuddyHoverTracker: ObservableObject {
    @Published private(set) var lookDirection: BuddyLookDirection = .none
    @Published private(set) var proximityLevel: BuddyProximityLevel = .far

    private var monitor: Any?
    private var notchCenter: CGPoint = .zero

    func start(notchCenterX: CGFloat) {
        let screenHeight = NSScreen.main?.frame.height ?? 900
        notchCenter = CGPoint(x: notchCenterX, y: screenHeight)

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMove(event.locationInWindow)
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleMouseMove(_ mouseLocation: CGPoint) {
        let dx = mouseLocation.x - notchCenter.x
        let dy = mouseLocation.y - notchCenter.y
        let distance = sqrt(dx * dx + dy * dy)

        let newProximity: BuddyProximityLevel
        if distance < 50 {
            newProximity = .over
        } else if distance < 200 {
            newProximity = .near
        } else {
            newProximity = .far
        }

        let newDirection: BuddyLookDirection
        if newProximity == .far {
            newDirection = .none
        } else if abs(dx) < 30 {
            newDirection = .center
        } else if dx < 0 {
            newDirection = .left
        } else {
            newDirection = .right
        }

        if newProximity != proximityLevel {
            proximityLevel = newProximity
        }
        if newDirection != lookDirection {
            lookDirection = newDirection
        }
    }
}
