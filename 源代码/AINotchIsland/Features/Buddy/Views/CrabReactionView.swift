import SwiftUI

struct CrabReactionView: View {
    let scene: CrabScene
    var pixelSize: CGFloat = 3.0
    var showAnimation: Bool = true

    @State private var appeared = false

    private var sprite: [[PixelColor]] {
        CrabReactionView.spriteFor(scene)
    }

    var body: some View {
        let palette = CatColorPalette.crab
        let rows = sprite.count
        let cols = sprite.first?.count ?? 0

        VStack(spacing: 0) {
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
        .scaleEffect(appeared ? 1.0 : 0.5)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            guard showAnimation else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }

    static func spriteFor(_ scene: CrabScene) -> [[PixelColor]] {
        switch scene {
        case .idle: return CatSprites.idle
        case .sleeping: return CatSprites.sleeping
        case .sunglasses: return CatSprites.sunglasses
        case .waving: return CatSprites.waving
        case .coding: return CatSprites.working
        case .reading: return CatSprites.reading
        case .thinking: return CatSprites.thinking
        case .watching: return CatSprites.watching
        case .music: return CatSprites.music
        case .confused: return CatSprites.confused
        case .nervous: return CatSprites.nervous
        case .surprised: return CatSprites.error
        case .happy: return CatSprites.happy
        case .celebrating: return CatSprites.celebrating
        case .tired: return CatSprites.tired
        case .charging: return CatSprites.charging
        case .lowBattery: return CatSprites.lowBattery
        case .fullBattery: return CatSprites.fullBattery
        case .wifiConnected: return CatSprites.wifiConnected
        case .wifiLost: return CatSprites.wifiLost
        case .vpnConnected: return CatSprites.vpnConnected
        case .hotspotActive: return CatSprites.hotspotActive
        case .bluetoothConnected: return CatSprites.bluetoothConnected
        case .listeningMusic: return CatSprites.listeningMusic
        case .volumeUp: return CatSprites.volumeUp
        case .volumeMute: return CatSprites.volumeMute
        case .brightnessChange: return CatSprites.brightnessChange
        case .screenRecording: return CatSprites.screenRecording
        case .screenshot: return CatSprites.screenshot
        case .mirrorDisplay: return CatSprites.mirrorDisplay
        case .focusOn: return CatSprites.focusOn
        case .focusOff: return CatSprites.focusOff
        case .lockScreen: return CatSprites.lockScreen
        case .usbConnected: return CatSprites.usbConnected
        case .usbEjected: return CatSprites.usbEjected
        case .airdropReceiving: return CatSprites.airdropReceiving
        case .nightOwl: return CatSprites.nightOwl
        case .morningStretch: return CatSprites.morningStretch
        case .downloading: return CatSprites.downloading
        case .idleLookLeft: return CatSprites.idleLookLeft
        case .idleLookRight: return CatSprites.idleLookRight
        case .idleYawn: return CatSprites.idleYawn
        case .idleBob: return CatSprites.idleBob
        case .idleScratch: return CatSprites.idleScratch
        case .idleDance: return CatSprites.idleDance
        case .idleChaseButterfly: return CatSprites.idleChaseButterfly
        case .idleSitDown: return CatSprites.idleSitDown
        case .idlePeek: return CatSprites.idlePeek
        case .idleCurious: return CatSprites.idleCurious
        case .idleDoze: return CatSprites.idleDoze
        case .idleStretch: return CatSprites.idleStretch
        case .weatherRainy: return CatSprites.weatherRainy
        case .weatherCold: return CatSprites.weatherCold
        case .weatherHot: return CatSprites.weatherHot
        case .dizzy: return CatSprites.dizzy
        case .cuddleSleep: return CatSprites.cuddleSleep
        case .danceSpin: return CatSprites.danceSpin
        }
    }
}
