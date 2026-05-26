import Foundation
internal import AppKit
@preconcurrency import AVFoundation
import os.log

enum SoundEvent: String, CaseIterable {
    case sessionStart
    case taskComplete
    case taskError
    case approvalNeeded
    case contextLimit
    case idleReminder
    case taskAcknowledge
    case spamDetected

    var displayName: String {
        switch self {
        case .sessionStart: return L10n.app("agent.sound.sessionStart", fallback: "Session Start")
        case .taskComplete: return L10n.app("agent.sound.taskComplete", fallback: "Task Complete")
        case .taskError: return L10n.app("agent.sound.taskError", fallback: "Task Error")
        case .approvalNeeded: return L10n.app("agent.sound.approvalNeeded", fallback: "Approval Needed")
        case .contextLimit: return L10n.app("agent.sound.contextLimit", fallback: "Context Limit")
        case .idleReminder: return L10n.app("agent.sound.idleReminder", fallback: "Idle Reminder")
        case .taskAcknowledge: return L10n.app("agent.sound.taskAcknowledge", fallback: "Task Acknowledge")
        case .spamDetected: return L10n.app("agent.sound.spamDetected", fallback: "Spam Detected")
        }
    }
}

enum SoundTheme: String {
    case system, minimal, retro, custom
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    var isEnabled = true
    var volume: Double = 0.7
    // Default to macOS system sounds (Glass / Ping / Pop / Funk / etc) —
    // they match the OS look-and-feel and don't surprise the user with
    // synthesized tones. Users can still pick .minimal or .retro from
    // Settings → Agent Halo → Sounds.
    var theme: SoundTheme = .system
    var quietHoursEnabled = false
    var quietHoursStart = 22
    var quietHoursEnd = 8
    var disabledEvents: Set<SoundEvent> = []

    private let systemSounds: [String: String] = [
        "sessionStart": "Blow",
        "taskComplete": "Glass",
        "taskError": "Basso",
        "approvalNeeded": "Ping",
        "contextLimit": "Sosumi",
        "idleReminder": "Tink",
        "taskAcknowledge": "Pop",
        "spamDetected": "Funk"
    ]

    func play(_ event: SoundEvent) {
        guard isEnabled else { return }
        guard !disabledEvents.contains(event) else { return }
        guard !isInQuietHours() else { return }

        switch theme {
        case .system:
            playSystemSound(event)
        case .minimal:
            playMinimalSound(event)
        case .retro:
            playRetroSound(event)
        case .custom:
            playSystemSound(event)
        }
    }

    private func playSystemSound(_ event: SoundEvent) {
        guard let soundName = systemSounds[event.rawValue] else { return }
        if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.volume = Float(volume)
            sound.play()
        }
    }

    private func playMinimalSound(_ event: SoundEvent) {
        let frequency: Double
        let duration: Double

        switch event {
        case .sessionStart: frequency = 880; duration = 0.1
        case .taskComplete: frequency = 1047; duration = 0.15
        case .taskError: frequency = 220; duration = 0.2
        case .approvalNeeded: frequency = 660; duration = 0.12
        case .contextLimit: frequency = 440; duration = 0.18
        case .idleReminder: frequency = 523; duration = 0.08
        case .taskAcknowledge: frequency = 740; duration = 0.06
        case .spamDetected: frequency = 330; duration = 0.25
        }

        playSynthTone(frequency: frequency, duration: duration)
    }

    private func playRetroSound(_ event: SoundEvent) {
        let frequency: Double
        switch event {
        case .sessionStart: frequency = 523.25
        case .taskComplete: frequency = 783.99
        case .taskError: frequency = 261.63
        case .approvalNeeded: frequency = 659.25
        case .contextLimit: frequency = 349.23
        case .idleReminder: frequency = 440.0
        case .taskAcknowledge: frequency = 587.33
        case .spamDetected: frequency = 293.66
        }
        playSynthTone(frequency: frequency, duration: 0.15)
    }

    private func playSynthTone(frequency: Double, duration: Double) {
        let sampleRate: Double = 44100
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, min(t * 20, (duration - t) * 20))
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * volume)
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
        buffer.frameLength = AVAudioFrameCount(numSamples)

        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<numSamples {
                channelData[i] = samples[i]
            }
        }

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            playerNode.scheduleBuffer(buffer) { [engine] in
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                    engine.stop()
                }
            }
            playerNode.play()
        } catch {
            AppLogger.agentHalo.error("Audio error: \(error.localizedDescription)")
        }
    }

    private func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        } else {
            return hour >= quietHoursStart || hour < quietHoursEnd
        }
    }
}
