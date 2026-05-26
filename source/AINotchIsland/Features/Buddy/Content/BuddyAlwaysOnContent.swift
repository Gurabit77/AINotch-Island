import SwiftUI
import Combine

struct BuddyAlwaysOnContent: NotchContentProtocol {
    let id = NotchContentRegistry.Buddy.alwaysOn.id
    var priority: Int { NotchContentRegistry.Buddy.alwaysOn.priority }
    var isExpandable: Bool { false }

    let engine: CatAnimationEngine
    let scheduler: BuddyIdleScheduler
    let emotionState: BuddyEmotionState
    let hoverTracker: BuddyHoverTracker
    let environmentService: BuddyEnvironmentService

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 50, height: baseHeight + 4)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(BuddyAlwaysOnView(
            engine: engine,
            scheduler: scheduler,
            emotionState: emotionState,
            hoverTracker: hoverTracker,
            environmentService: environmentService
        ))
    }
}
