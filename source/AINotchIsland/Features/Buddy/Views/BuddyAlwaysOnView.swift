import SwiftUI
import Combine

struct BuddyAlwaysOnView: View {
    @Environment(\.notchScale) var scale
    @ObservedObject var engine: CatAnimationEngine
    @ObservedObject var scheduler: BuddyIdleScheduler
    @ObservedObject var emotionState: BuddyEmotionState
    @ObservedObject var hoverTracker: BuddyHoverTracker
    @ObservedObject var environmentService: BuddyEnvironmentService
    @State private var bounceScale: CGFloat = 1.0
    @State private var tapTimestamps: [Date] = []

    var body: some View {
        HStack {
            PixelCatView(mood: .idle, engine: engine)
                .scaleEffect(0.75 * bounceScale)
                .onTapGesture(count: 2) {
                    engine.dance()
                    emotionState.recordDance()
                    triggerBounce()
                }
                .onTapGesture(count: 1) {
                    handleTap()
                }
                .onLongPressGesture(minimumDuration: 1.5) {
                    engine.cuddle()
                }
            Spacer()
        }
        .padding(.horizontal, 14.scaled(by: scale))
        .onAppear {
            engine.start()
            scheduler.start()
        }
        .onDisappear {
            engine.stop()
            scheduler.stop()
        }
        .onReceive(scheduler.$currentBehavior) { behavior in
            engine.playIdleBehavior(behavior)
        }
        .onReceive(emotionState.$computedMood) { mood in
            scheduler.updateMood(mood)
        }
        .onReceive(hoverTracker.$proximityLevel.combineLatest(hoverTracker.$lookDirection)) { pair in
            engine.handleHover(direction: pair.1, proximity: pair.0)
        }
        .onReceive(environmentService.$weatherScene) { scene in
            if let scene {
                engine.showTemporaryScene(scene, duration: 10)
            }
        }
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            bounceScale = 1.12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }
        }
    }

    private func handleTap() {
        let now = Date()
        tapTimestamps.append(now)
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 2 }

        if tapTimestamps.count >= 4 {
            engine.showTemporaryScene(.dizzy, duration: 2.0)
            tapTimestamps = []
        } else {
            engine.pet()
            emotionState.recordPet()
        }
        triggerBounce()
    }
}
