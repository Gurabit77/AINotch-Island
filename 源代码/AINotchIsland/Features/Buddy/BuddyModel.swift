import SwiftUI

enum PixelColor {
    case clear, body, bodyLight, dark, eye, nose
}

enum CatMood {
    case idle, working, waiting, error, happy

    static func from(status: AgentGlobalStatus) -> CatMood {
        switch status {
        case .idle: return .idle
        case .working: return .working
        case .waitingApproval: return .waiting
        case .error: return .error
        }
    }
}

enum CatEventOverlay: Equatable {
    case toolDone, approvalNeeded, errorOccurred, sessionComplete, heartPet
}

enum CrabScene: Equatable {
    // A: Agent work (existing 15)
    case idle, sleeping, sunglasses, waving
    case coding, reading, thinking, watching, music
    case confused, nervous, surprised
    case happy, celebrating, tired

    // B: Power/Battery
    case charging, lowBattery, fullBattery

    // C: Network
    case wifiConnected, wifiLost, vpnConnected, hotspotActive, bluetoothConnected

    // D: Media/Audio
    case listeningMusic, volumeUp, volumeMute, brightnessChange

    // E: Screen/Recording
    case screenRecording, screenshot, mirrorDisplay

    // F: Focus/System
    case focusOn, focusOff, lockScreen

    // G: External Devices
    case usbConnected, usbEjected, airdropReceiving

    // H: Environment/Time
    case nightOwl, morningStretch, downloading

    // I: Idle companion behaviors
    case idleLookLeft, idleLookRight, idleYawn, idleBob
    case idleScratch, idleDance, idleChaseButterfly, idleSitDown
    case idlePeek, idleCurious, idleDoze, idleStretch

    // J: Companion interactions & weather
    case weatherRainy, weatherCold, weatherHot
    case dizzy, cuddleSleep, danceSpin
}

enum BuddyMood: String, CaseIterable {
    case happy, content, neutral, tired, lonely

    static func compute(affection: Int, energy: Int, lastInteraction: Date) -> BuddyMood {
        let hoursSinceInteraction = Date().timeIntervalSince(lastInteraction) / 3600
        if affection > 80 && energy > 60 { return .happy }
        if affection > 50 && energy > 40 { return .content }
        if energy < 30 { return .tired }
        if affection < 30 && hoursSinceInteraction > 4 { return .lonely }
        return .neutral
    }
}

struct CatColorPalette {
    let body: Color
    let bodyLight: Color
    let dark: Color
    let eye: Color
    let nose: Color

    static let crab = CatColorPalette(
        body: Color(red: 0.84, green: 0.48, blue: 0.35),
        bodyLight: Color(red: 0.88, green: 0.55, blue: 0.42),
        dark: Color(red: 0.25, green: 0.15, blue: 0.12),
        eye: Color(red: 0.12, green: 0.08, blue: 0.06),
        nose: Color(red: 0.25, green: 0.15, blue: 0.12)
    )

    static func forMood(_ mood: CatMood) -> CatColorPalette {
        return crab
    }

    func resolve(_ pixel: PixelColor) -> Color? {
        switch pixel {
        case .clear: return nil
        case .body: return body
        case .bodyLight: return bodyLight
        case .dark: return dark
        case .eye: return eye
        case .nose: return nose
        }
    }
}
