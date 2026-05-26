import Foundation
import Combine

@MainActor
final class BuddyIdleScheduler: ObservableObject {
    @Published private(set) var currentBehavior: CrabScene = .idle

    private var timer: AnyCancellable?
    private var lastBehavior: CrabScene = .idle
    private var mood: BuddyMood = .neutral

    private struct WeightedScene {
        let scene: CrabScene
        let weight: Double
    }

    func start() {
        scheduleNext()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func updateMood(_ newMood: BuddyMood) {
        mood = newMood
    }

    private func scheduleNext() {
        let delay = Double.random(in: 3...8)
        timer?.cancel()
        timer = Timer.publish(every: delay, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.pickNextBehavior()
                self?.scheduleNext()
            }
    }

    private func pickNextBehavior() {
        let candidates = weightedScenes(for: mood)
        let filtered = candidates.filter { $0.scene != lastBehavior }
        let pool = filtered.isEmpty ? candidates : filtered

        let totalWeight = pool.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<totalWeight)

        for item in pool {
            roll -= item.weight
            if roll <= 0 {
                lastBehavior = currentBehavior
                currentBehavior = item.scene
                return
            }
        }

        lastBehavior = currentBehavior
        currentBehavior = pool.last?.scene ?? .idle
    }

    private func weightedScenes(for mood: BuddyMood) -> [WeightedScene] {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 22 || hour < 6
        let isMorning = hour >= 6 && hour < 10

        switch mood {
        case .happy:
            return [
                .init(scene: .idleDance, weight: 30),
                .init(scene: .idleChaseButterfly, weight: 20),
                .init(scene: .idleLookLeft, weight: 10),
                .init(scene: .idleLookRight, weight: 10),
                .init(scene: .idleBob, weight: 20),
                .init(scene: .idleScratch, weight: 10),
            ]
        case .content:
            return [
                .init(scene: .idleBob, weight: 35),
                .init(scene: .idleLookLeft, weight: 15),
                .init(scene: .idleLookRight, weight: 15),
                .init(scene: .idleScratch, weight: 15),
                .init(scene: .idleDance, weight: 10),
                .init(scene: .idleChaseButterfly, weight: 10),
            ]
        case .neutral:
            return [
                .init(scene: .idleBob, weight: 40),
                .init(scene: .idleLookLeft, weight: 15),
                .init(scene: .idleLookRight, weight: 15),
                .init(scene: .idleYawn, weight: isNight ? 15 : 10),
                .init(scene: .idleScratch, weight: 10),
                .init(scene: .idleStretch, weight: isMorning ? 15 : 5),
            ]
        case .tired:
            return [
                .init(scene: .idleDoze, weight: 35),
                .init(scene: .idleSitDown, weight: 25),
                .init(scene: .idleYawn, weight: 20),
                .init(scene: .idleBob, weight: 10),
                .init(scene: .idleLookLeft, weight: 5),
                .init(scene: .idleLookRight, weight: 5),
            ]
        case .lonely:
            return [
                .init(scene: .idlePeek, weight: 30),
                .init(scene: .idleSitDown, weight: 20),
                .init(scene: .idleLookLeft, weight: 15),
                .init(scene: .idleLookRight, weight: 15),
                .init(scene: .idleCurious, weight: 10),
                .init(scene: .idleBob, weight: 10),
            ]
        }
    }
}
