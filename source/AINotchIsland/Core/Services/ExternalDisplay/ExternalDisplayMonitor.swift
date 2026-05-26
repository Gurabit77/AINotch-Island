import Foundation
import Combine
import CoreGraphics

@MainActor
final class ExternalDisplayMonitor: ObservableObject {
    @Published var event: ExternalDisplayEvent?
    @Published private(set) var externalDisplayCount: Int = 0

    private var previousCount: Int = 0

    func start() {
        previousCount = currentExternalDisplayCount()
        externalDisplayCount = previousCount

        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            guard let userInfo else { return }
            let monitor = Unmanaged<ExternalDisplayMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.handleReconfiguration()
            }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    func stop() {
        CGDisplayRemoveReconfigurationCallback({ displayID, flags, userInfo in
            // no-op matching callback
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func handleReconfiguration() {
        let newCount = currentExternalDisplayCount()
        guard newCount != previousCount else { return }

        if newCount > previousCount {
            event = .connected
        } else {
            event = .disconnected
        }

        previousCount = newCount
        externalDisplayCount = newCount
    }

    private func currentExternalDisplayCount() -> Int {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(16, nil, &displayCount)
        return max(0, Int(displayCount) - 1)
    }
}

enum ExternalDisplayEvent {
    case connected
    case disconnected
}
