import SwiftUI

struct PixelCatView: View {
    let mood: CatMood
    @ObservedObject var engine: CatAnimationEngine

    private let pixelSize: CGFloat = 3.5

    var body: some View {
        ZStack(alignment: .topTrailing) {
            catGrid
            if let overlay = engine.activeOverlay {
                overlayBadge(overlay)
                    .offset(x: 5, y: -5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .offset(x: engine.nervousOffset)
        .contentShape(Rectangle())
        .onTapGesture { engine.pet() }
        .animation(.easeInOut(duration: 0.3), value: engine.currentScene)
        .animation(.easeInOut(duration: 0.2), value: engine.activeOverlay)
    }

    private var catGrid: some View {
        let sprite = currentSprite
        let rows = sprite.count
        let cols = sprite.first?.count ?? 0
        let palette = CatColorPalette.crab
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { col in
                        let pixel = sprite[row][col]
                        if let color = palette.resolve(pixel) {
                            RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                                .fill(color)
                                .frame(width: pixelSize, height: pixelSize)
                        } else {
                            Color.clear
                                .frame(width: pixelSize, height: pixelSize)
                        }
                    }
                }
            }
        }
    }

    private var currentSprite: [[PixelColor]] {
        let scene = engine.currentScene
        let frame = engine.currentFrame
        let blink = engine.isBlink

        switch scene {
        // A: Base & Agent states
        case .idle:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.idle
        case .sleeping:
            return frame == 1 ? CatSprites.sleeping : CatSprites.idleDoze
        case .sunglasses:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.sunglasses
        case .waving:
            return frame == 1 ? CatSprites.idle : CatSprites.waving
        case .coding:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.working
        case .reading:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.reading
        case .thinking:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.thinking
        case .watching:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.watching
        case .music:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleBob : CatSprites.music
        case .confused:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleLookLeft : CatSprites.confused
        case .nervous:
            if blink { return CatSprites.blink }
            return CatSprites.nervous
        case .surprised:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.confused : CatSprites.error
        case .happy:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.celebrating : CatSprites.happy
        case .celebrating:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.happy : CatSprites.celebrating
        case .tired:
            return frame == 1 ? CatSprites.idleDoze : CatSprites.tired

        // B: Power/Battery
        case .charging:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.charging
        case .lowBattery:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.tired : CatSprites.lowBattery
        case .fullBattery:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.celebrating : CatSprites.fullBattery

        // C: Network
        case .wifiConnected:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.wifiConnected
        case .wifiLost:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.confused : CatSprites.wifiLost
        case .vpnConnected:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.vpnConnected
        case .hotspotActive:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.hotspotActive
        case .bluetoothConnected:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.bluetoothConnected

        // D: Media/Audio
        case .listeningMusic:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleBob : CatSprites.listeningMusic
        case .volumeUp:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.volumeUp
        case .volumeMute:
            if blink { return CatSprites.blink }
            return CatSprites.volumeMute
        case .brightnessChange:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.brightnessChange

        // E: Screen/Recording
        case .screenRecording:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.screenRecording
        case .screenshot:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.screenshot
        case .mirrorDisplay:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.mirrorDisplay

        // F: Focus/System
        case .focusOn:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.focusOn
        case .focusOff:
            if blink { return CatSprites.blink }
            return CatSprites.focusOff
        case .lockScreen:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.lockScreen

        // G: External Devices
        case .usbConnected:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.usbConnected
        case .usbEjected:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.usbEjected
        case .airdropReceiving:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.airdropReceiving

        // H: Environment/Time
        case .nightOwl:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.nightOwl
        case .morningStretch:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleStretch : CatSprites.morningStretch
        case .downloading:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.downloading

        // I: Idle companion behaviors
        case .idleLookLeft:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idle : CatSprites.idleLookLeft
        case .idleLookRight:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idle : CatSprites.idleLookRight
        case .idleYawn:
            return frame == 1 ? CatSprites.idle : CatSprites.idleYawn
        case .idleBob:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idle : CatSprites.idleBob
        case .idleScratch:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idle : CatSprites.idleScratch
        case .idleDance:
            return frame == 1 ? CatSprites.danceSpin : CatSprites.idleDance
        case .idleChaseButterfly:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleLookRight : CatSprites.idleChaseButterfly
        case .idleSitDown:
            if blink { return CatSprites.blink }
            return CatSprites.idleSitDown
        case .idlePeek:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleCurious : CatSprites.idlePeek
        case .idleCurious:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idlePeek : CatSprites.idleCurious
        case .idleDoze:
            return frame == 1 ? CatSprites.sleeping : CatSprites.idleDoze
        case .idleStretch:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleSitDown : CatSprites.idleStretch

        // J: Companion interactions & weather
        case .weatherRainy:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.idleTail : CatSprites.weatherRainy
        case .weatherCold:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.nervous : CatSprites.weatherCold
        case .weatherHot:
            if blink { return CatSprites.blink }
            return frame == 1 ? CatSprites.tired : CatSprites.weatherHot
        case .dizzy:
            return frame == 1 ? CatSprites.confused : CatSprites.dizzy
        case .cuddleSleep:
            return frame == 1 ? CatSprites.sleeping : CatSprites.cuddleSleep
        case .danceSpin:
            return frame == 1 ? CatSprites.idleDance : CatSprites.danceSpin
        }
    }

    private func overlayBadge(_ overlay: CatEventOverlay) -> some View {
        let (pixels, color) = CatSprites.overlaySprite(overlay)
        let badgeSize: CGFloat = 2.5
        return VStack(spacing: 0) {
            ForEach(0..<pixels.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<pixels[row].count, id: \.self) { col in
                        if pixels[row][col] {
                            RoundedRectangle(cornerRadius: 0.3, style: .continuous)
                                .fill(color)
                                .frame(width: badgeSize, height: badgeSize)
                        } else {
                            Color.clear
                                .frame(width: badgeSize, height: badgeSize)
                        }
                    }
                }
            }
        }
        .shadow(color: color.opacity(0.6), radius: 2)
    }
}
