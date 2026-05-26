import Foundation
import Combine

@MainActor
final class BuddyEmotionState: ObservableObject {
    @Published var affection: Int {
        didSet { UserDefaults.standard.set(affection, forKey: Keys.affection) }
    }
    @Published var energy: Int {
        didSet { UserDefaults.standard.set(energy, forKey: Keys.energy) }
    }
    @Published var lastInteractionDate: Date {
        didSet { UserDefaults.standard.set(lastInteractionDate.timeIntervalSince1970, forKey: Keys.lastInteraction) }
    }
    @Published private(set) var computedMood: BuddyMood = .neutral

    private var decayTimer: AnyCancellable?
    private var interactionCooldown: Int = 0

    private enum Keys {
        static let affection = "buddy.emotion.affection"
        static let energy = "buddy.emotion.energy"
        static let lastInteraction = "buddy.emotion.lastInteraction"
    }

    init() {
        let defaults = UserDefaults.standard
        self.affection = defaults.object(forKey: Keys.affection) as? Int ?? 50
        self.energy = defaults.object(forKey: Keys.energy) as? Int ?? 70
        let timestamp = defaults.double(forKey: Keys.lastInteraction)
        self.lastInteractionDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date()
        self.computedMood = BuddyMood.compute(affection: affection, energy: energy, lastInteraction: lastInteractionDate)
    }

    func start() {
        decayTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stop() {
        decayTimer?.cancel()
        decayTimer = nil
    }

    func recordPet() {
        let gain = max(1, 5 - interactionCooldown)
        affection = min(100, affection + gain)
        energy = min(100, energy + 2)
        lastInteractionDate = Date()
        interactionCooldown = min(4, interactionCooldown + 1)
        recalculateMood()
    }

    func recordDance() {
        affection = min(100, affection + 3)
        energy = max(0, energy - 3)
        lastInteractionDate = Date()
        recalculateMood()
    }

    func recordPositiveEvent() {
        affection = min(100, affection + 1)
        recalculateMood()
    }

    private func tick() {
        // Affection decay: -2 per hour = -1 per 30 ticks (each tick = 60s)
        // Simplified: every 30 ticks (30 min), -1
        // Actually implement as fractional: every tick has 1/30 chance
        if Int.random(in: 0..<30) == 0 {
            affection = max(20, affection - 1)
        }

        // Energy: slowly recover when idle
        if energy < 80 {
            if Int.random(in: 0..<2) == 0 {
                energy = min(80, energy + 1)
            }
        }

        // Cooldown decay
        if interactionCooldown > 0 && Int.random(in: 0..<3) == 0 {
            interactionCooldown -= 1
        }

        recalculateMood()
    }

    private func recalculateMood() {
        let newMood = BuddyMood.compute(affection: affection, energy: energy, lastInteraction: lastInteractionDate)
        if newMood != computedMood {
            computedMood = newMood
        }
    }
}
