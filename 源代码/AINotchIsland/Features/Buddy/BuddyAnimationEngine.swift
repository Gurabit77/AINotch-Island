import SwiftUI
import Combine

@MainActor
final class CatAnimationEngine: ObservableObject {
    @Published var currentFrame: Int = 0
    @Published var isBlink: Bool = false
    @Published var isPetting: Bool = false
    @Published var activeOverlay: CatEventOverlay?
    @Published var currentScene: CrabScene = .waving
    @Published var nervousOffset: CGFloat = 0

    private(set) var idleTickCount: Int = 0
    private var timer: AnyCancellable?
    private var tick: Int = 0
    private var overlayDismissTask: Task<Void, Never>?
    private var temporarySceneTask: Task<Void, Never>?
    private var baseScene: CrabScene = .idle
    private var behaviorSequence: [CrabScene] = []
    private var behaviorSequenceIndex: Int = 0
    private var behaviorSequenceTask: Task<Void, Never>?

    private let idleSequence: [Int] = [0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0]

    func start() {
        currentScene = .waving
        temporarySceneTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.currentScene = self?.baseScene ?? .idle
        }
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.advance()
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func pet() {
        isPetting = true
        showOverlay(.heartPet)
        temporarySceneTask?.cancel()
        behaviorSequenceTask?.cancel()
        behaviorSequence = [.happy, .celebrating, .happy, .celebrating, .happy]
        behaviorSequenceIndex = 0
        playNextSequenceFrame()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isPetting = false
        }
    }

    func updateScene(_ scene: CrabScene) {
        baseScene = scene
        if !isPetting && temporarySceneTask == nil {
            currentScene = scene
        }
        if scene != .idle && scene != .sleeping && scene != .waving {
            idleTickCount = 0
        }
    }

    func showTemporaryScene(_ scene: CrabScene, duration: Double = 3.0) {
        temporarySceneTask?.cancel()
        currentScene = scene
        temporarySceneTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.temporarySceneTask = nil
            self?.currentScene = self?.baseScene ?? .idle
        }
    }

    func showOverlay(_ overlay: CatEventOverlay) {
        overlayDismissTask?.cancel()
        activeOverlay = overlay
        overlayDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.activeOverlay = nil
        }
    }

    func playIdleBehavior(_ scene: CrabScene) {
        guard !isPetting else { return }
        guard temporarySceneTask == nil else { return }

        behaviorSequenceTask?.cancel()

        let sequence = behaviorFrames(for: scene)
        if sequence.isEmpty {
            currentScene = scene
            baseScene = scene
        } else {
            behaviorSequence = sequence
            behaviorSequenceIndex = 0
            playNextSequenceFrame()
        }
    }

    func dance() {
        temporarySceneTask?.cancel()
        behaviorSequenceTask?.cancel()
        behaviorSequence = [.idleDance, .danceSpin, .idleDance, .danceSpin, .celebrating, .happy]
        behaviorSequenceIndex = 0
        playNextSequenceFrame()
    }

    func cuddle() {
        temporarySceneTask?.cancel()
        behaviorSequenceTask?.cancel()
        behaviorSequence = [.idleSitDown, .idleDoze, .sleeping, .cuddleSleep]
        behaviorSequenceIndex = 0
        playNextSequenceFrame()
    }

    func handleHover(direction: BuddyLookDirection, proximity: BuddyProximityLevel) {
        guard !isPetting else { return }
        guard temporarySceneTask == nil else { return }
        guard baseScene != .cuddleSleep else { return }

        switch proximity {
        case .over:
            behaviorSequenceTask?.cancel()
            currentScene = .idleCurious
        case .near:
            behaviorSequenceTask?.cancel()
            switch direction {
            case .left: currentScene = .idleLookLeft
            case .right: currentScene = .idleLookRight
            case .center: currentScene = .idlePeek
            case .none: break
            }
        case .far:
            if currentScene == .idleLookLeft || currentScene == .idleLookRight ||
               currentScene == .idleCurious || currentScene == .idlePeek {
                currentScene = baseScene
            }
        }
    }

    private func playNextSequenceFrame() {
        guard behaviorSequenceIndex < behaviorSequence.count else {
            behaviorSequence = []
            behaviorSequenceIndex = 0
            currentScene = baseScene
            return
        }

        let frame = behaviorSequence[behaviorSequenceIndex]
        currentScene = frame
        behaviorSequenceIndex += 1

        behaviorSequenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            self?.playNextSequenceFrame()
        }
    }

    private func behaviorFrames(for scene: CrabScene) -> [CrabScene] {
        switch scene {
        case .idleChaseButterfly:
            return [.idleLookRight, .idleChaseButterfly, .idleChaseButterfly, .idleLookLeft, .idleLookRight, .idle]
        case .idleYawn:
            return [.idle, .idleYawn, .idleYawn, .idleYawn, .idle]
        case .idleStretch:
            return [.idleSitDown, .idleStretch, .idleStretch, .idleSitDown, .idle]
        case .idleScratch:
            return [.idle, .idleScratch, .idleScratch, .idleScratch, .idle]
        case .idleDance:
            return [.idleDance, .danceSpin, .idleDance, .danceSpin, .idle]
        case .idleBob:
            return [.idle, .idleBob, .idle, .idleBob, .idle]
        case .idlePeek:
            return [.idle, .idlePeek, .idleCurious, .idlePeek, .idle]
        case .idleDoze:
            return [.idle, .idleSitDown, .idleDoze, .idleDoze, .sleeping, .idleDoze, .idle]
        case .idleCurious:
            return [.idle, .idlePeek, .idleCurious, .idleLookLeft, .idleLookRight, .idle]
        case .idleLookLeft:
            return [.idle, .idleLookLeft, .idleLookLeft, .idle]
        case .idleLookRight:
            return [.idle, .idleLookRight, .idleLookRight, .idle]
        default:
            return []
        }
    }

    private func advance() {
        tick += 1
        let step = idleSequence[tick % idleSequence.count]

        if isPetting {
            currentFrame = tick % 2
            isBlink = false
        } else if step == -1 {
            currentFrame = 0
            isBlink = true
        } else {
            currentFrame = step
            isBlink = false
        }

        if baseScene == .idle || baseScene == .sleeping || baseScene == .waving {
            idleTickCount += 1
        }

        if currentScene == .nervous {
            nervousOffset = CGFloat.random(in: -1.5...1.5)
        } else {
            nervousOffset = 0
        }
    }
}
