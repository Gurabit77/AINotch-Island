import SwiftUI

enum CatSprites {
    private typealias P = PixelColor

    // MARK: - Crab Frames (11 wide × 7 tall) — horizontal rectangle + 4 legs

    static let idle: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    static let idleTail: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, L, B, C, C, C, B, L, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    static let blink: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - Scene Sprites

    // Working: typing on keyboard
    static let working: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, D, D, D, D, D, D, D, D, C],
            [C, D, N, D, N, D, N, D, N, D, C],
        ]
    }()

    // Error: surprised wide eyes + open mouth
    static let error: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, E, E, B, B, B, E, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Happy: squinty eyes + smile
    static let happy: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Confused: asymmetric eyes + question mark
    static let confused: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, N, N],
            [C, B, B, B, B, B, B, B, B, C, N],
            [C, B, B, E, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, D, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Tired: droopy half-closed eyes + zzz
    static let tired: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, N, N],
            [C, B, B, B, B, B, B, B, B, N, C],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, C, E, B, B, B, C, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Music: headphones band on top
    static let music: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, D, D, D, D, D, D, D, D, D, C],
            [C, D, B, B, B, B, B, B, B, D, C],
            [C, D, B, E, B, B, B, E, B, D, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Sunglasses: dark band across eyes
    static let sunglasses: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [D, D, D, D, D, B, D, D, D, D, D],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Watching: eyes looking sideways + screen glow
    static let watching: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, E, B, B, B, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, N, N, N, N, N, N, N, N, N, C],
        ]
    }()

    // Sleeping: body flattened, eyes closed, ZZZ top-right
    static let sleeping: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, C, C, C, N, N, N],
            [C, C, C, C, C, C, C, C, C, N, C],
            [C, C, B, B, B, B, B, B, B, C, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, C, B, B, B, B, B, B, B, C, C],
        ]
    }()

    // Reading: eyes looking down, book/file at bottom
    static let reading: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, N, N, D, D, D, D, D, N, N, C],
        ]
    }()

    // Thinking: eyes looking up, thought bubble top-right
    static let thinking: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, N, N],
            [C, B, B, B, B, B, B, B, B, C, N],
            [C, B, E, B, B, B, E, B, B, N, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Nervous: big round eyes, open mouth, shaky
    static let nervous: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, E, E, B, B, B, E, E, B, C],
            [C, B, E, E, B, B, B, E, E, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Waving: one claw raised on the right side
    static let waving: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, B],
            [C, B, B, B, B, B, B, B, B, B, B],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Celebrating: happy eyes + star decorations on sides
    static let celebrating: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [N, C, B, B, C, C, C, B, B, C, N],
            [C, B, B, B, B, B, B, B, B, B, C],
            [N, B, B, D, B, B, B, D, B, B, N],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - B Group: Power/Battery Sprites

    // Charging: excited face + zigzag lightning bolt above
    static let charging: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, N, N, N, C, C, C, C],
            [C, B, B, B, B, N, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Low battery: droopy, sweating, lying low
    static let lowBattery: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, C, C, C, C, N, C],
            [C, C, C, C, C, C, C, C, C, C, N],
            [C, C, B, B, B, B, B, B, B, C, C],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, C, E, B, B, B, C, E, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, C, B, B, B, B, B, B, B, C, C],
        ]
    }()

    // Full battery: energized glow, claws up + L highlight body
    static let fullBattery: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [B, C, B, B, C, N, C, B, B, C, B],
            [B, B, L, L, L, L, L, L, L, B, B],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, L, B, B, B, B, B, L, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - C Group: Network Sprites

    // WiFi connected: signal arcs above head
    static let wifiConnected: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, N, C, N, C, N, C, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // WiFi lost: panicked, X marks where signal was
    static let wifiLost: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, N, C, D, C, N, C, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, E, E, B, B, B, E, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, D, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // VPN connected: shield shape on top, calm secure expression
    static let vpnConnected: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, N, N, N, N, N, C, C, C],
            [C, B, B, B, N, B, N, B, B, B, C],
            [C, B, B, E, B, N, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Hotspot active: antenna on head, proud stance
    static let hotspotActive: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, N, C, C, C, C, C],
            [C, B, B, B, B, N, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Bluetooth connected: BT rune on head + earpiece side
    static let bluetoothConnected: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, N, C, B, B, C, C],
            [C, B, B, B, B, N, N, B, B, N, C],
            [C, B, B, E, B, N, B, E, B, N, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - D Group: Media/Audio Sprites

    // Listening to music: eyes closed happily, musical notes floating
    static let listeningMusic: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, N, C],
            [C, B, B, B, B, B, B, B, B, C, N],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Volume up: covering ears with claws extended outward
    static let volumeUp: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [D, B, B, B, B, B, B, B, B, B, D],
            [D, B, B, E, B, B, B, E, B, B, D],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Volume mute: cross-shaped X mouth, one claw at lips
    static let volumeMute: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, D, B, D, B, B, C],
            [C, B, B, B, D, B, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Brightness change: squinting eyes
    static let brightnessChange: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, N, B, B, C, C, C, B, B, N, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, D, D, D, B, D, D, D, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - E Group: Screen/Recording Sprites

    // Screen recording: camera body on top + red rec dot
    static let screenRecording: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, D, D, D, D, D, D, D, N, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Screenshot: camera flash burst, dazzled squinting eyes
    static let screenshot: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [N, C, B, B, N, C, N, B, B, C, N],
            [C, B, B, B, B, N, B, B, B, B, C],
            [C, B, D, D, D, B, D, D, D, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Mirror display: eyes darting between two screen indicators
    static let mirrorDisplay: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [N, C, B, B, C, C, C, B, B, C, N],
            [N, B, B, B, B, B, B, B, B, B, N],
            [C, B, E, B, B, B, B, B, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [N, N, N, D, C, C, C, D, N, N, N],
        ]
    }()

    // MARK: - F Group: Focus/System Sprites

    // Focus on: ear covers on sides, furrowed determined brow
    static let focusOn: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, N, B, D, B, B, B, D, B, N, C],
            [C, N, B, E, B, B, B, E, B, N, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Focus off: relaxed slouch, half-closed happy eyes, no arms up
    static let focusOff: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, C, D, C, D, C, D, C, D, C, C],
        ]
    }()

    // Lock screen: padlock shape above head, guarding stance
    static let lockScreen: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, D, D, D, C, C, C, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, E, D, D, D, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - G Group: External Device Sprites

    // USB connected: curious wide eyes, USB plug shape on right
    static let usbConnected: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, N, N],
            [C, B, E, E, B, B, B, E, E, N, N],
            [C, B, B, B, B, B, B, B, B, N, N],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // USB ejected: sad eyes watching right, device leaving
    static let usbEjected: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, E, B, B, B, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, N],
            [C, B, B, D, B, B, B, D, B, N, N],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // AirDrop receiving: arms up catching file from above
    static let airdropReceiving: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, B, C, N, N, N, N, N, C, B, C],
            [C, B, B, B, B, N, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - H Group: Environment/Time Sprites

    // Night owl: crescent moon hat top-left, star-shaped eyes
    static let nightOwl: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, N, N, C, C, C, C, B, B, C, C],
            [C, N, B, B, B, B, B, B, B, B, C],
            [C, B, B, N, B, B, B, N, B, B, C],
            [C, B, N, N, N, B, N, N, N, B, C],
            [C, B, B, N, B, B, B, N, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Morning stretch: yawning wide open mouth, one arm up
    static let morningStretch: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, B],
            [C, B, B, B, B, B, B, B, B, B, B],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, C, E, B, B, B, C, E, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, D, B, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Downloading: eyes looking down at progress bar, eager
    static let downloading: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, D, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, N, N, N, N, D, D, D, D, C],
        ]
    }()

    // MARK: - I Group: Idle Companion Sprites

    // Idle look left: eyes shifted to the left side
    static let idleLookLeft: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, E, B, B, B, E, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle look right: eyes shifted to the right side
    static let idleLookRight: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, E, B, B, B, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle yawn: wide open mouth, half-closed eyes
    static let idleYawn: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, C, E, B, B, B, C, E, B, C],
            [C, B, B, D, D, D, D, D, B, B, C],
            [C, B, B, D, C, C, C, D, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle bob: body shifted up 1px (breathing animation frame)
    static let idleBob: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, C, C, D, C, C, C, D, C, C, C],
        ]
    }()

    // Idle scratch: one claw touching head
    static let idleScratch: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, B, C],
            [C, B, B, B, B, B, B, B, D, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle dance: body tilted, claws up, happy
    static let idleDance: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [B, C, B, B, C, C, C, B, B, C, B],
            [B, B, B, B, B, B, B, B, B, B, B],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, C, D, C, D, C, D, C, D, C, C],
        ]
    }()

    // Idle chase butterfly: looking up at a tiny butterfly above
    static let idleChaseButterfly: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, N, N, C, C, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, E, B, B, B, B, B, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle sit down: body squished low, legs tucked
    static let idleSitDown: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, C, C, C, C, C, C],
            [C, C, C, C, C, C, C, C, C, C, C],
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
        ]
    }()

    // Idle peek: half body visible from side
    static let idlePeek: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, C, C, B, B, C, C],
            [C, C, C, C, C, B, B, B, B, B, C],
            [C, C, C, C, C, B, B, E, B, B, C],
            [C, C, C, C, C, B, B, B, B, B, C],
            [C, C, C, C, C, B, B, B, B, B, C],
            [C, C, C, C, C, B, B, B, B, B, C],
            [C, C, C, C, C, C, D, C, D, C, C],
        ]
    }()

    // Idle curious: head tilted, big wide eyes
    static let idleCurious: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, B, B, C, C, B, B, C, C],
            [C, C, B, B, B, B, B, B, B, B, C],
            [C, C, B, E, E, B, B, E, E, B, C],
            [C, C, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, B, D, B, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle doze: half-closed eyes, slightly drooping
    static let idleDoze: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Idle stretch: arms extended wide, back arched
    static let idleStretch: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [B, C, B, B, C, C, C, B, B, C, B],
            [B, B, B, B, B, B, B, B, B, B, B],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, C, E, B, B, B, C, E, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, C, B, B, B, B, B, B, B, C, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // MARK: - J Group: Companion Interactions & Weather

    // Weather rainy: umbrella-like shape above head
    static let weatherRainy: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, N, N, N, N, N, N, N, C, C],
            [C, B, B, B, B, N, B, B, B, B, C],
            [C, B, B, E, B, B, B, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Weather cold: curled up tight, shivering
    static let weatherCold: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, C, C, C, C, C, C],
            [C, C, C, C, C, C, C, C, C, C, C],
            [C, C, B, B, B, B, B, B, B, C, C],
            [C, B, B, E, E, B, E, E, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, D, D, D, D, B, B, C],
            [C, C, B, B, B, B, B, B, B, C, C],
        ]
    }()

    // Weather hot: fanning with claws, sweat drop
    static let weatherHot: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, N],
            [C, B, B, B, B, B, B, B, B, B, N],
            [C, B, D, D, B, B, B, D, D, B, C],
            [C, B, C, E, B, B, B, C, E, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [B, B, B, B, B, B, B, B, B, B, B],
            [C, D, C, D, C, C, C, D, C, D, C],
        ]
    }()

    // Dizzy: spiral eyes from too many clicks
    static let dizzy: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, N, B, B, C, C, C, B, B, N, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, N, E, N, B, N, E, N, B, C],
            [C, B, B, N, B, B, B, N, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, C, D, C, D, C, D, C, D, C, C],
        ]
    }()

    // Cuddle sleep: curled up cutely, heart nearby
    static let cuddleSleep: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, C, C, C, C, C, N, C, N, C],
            [C, C, C, C, C, C, C, N, N, N, C],
            [C, C, B, B, B, B, B, B, B, C, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, B, D, C, D, B, B, B, C],
            [C, C, B, B, B, B, B, B, B, C, C],
        ]
    }()

    // Dance spin: rotated posture, one leg up
    static let danceSpin: [[PixelColor]] = {
        let C = P.clear, B = P.body, L = P.bodyLight, D = P.dark, E = P.eye, N = P.nose
        return [
            [C, C, B, B, C, C, C, B, B, C, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, B, B, B, B, B, B, C],
            [C, B, B, D, B, B, B, D, B, B, C],
            [C, B, B, B, D, D, D, B, B, B, C],
            [C, D, C, C, C, C, C, C, C, D, C],
        ]
    }()

    // MARK: - Event Overlay Symbols

    static func overlaySprite(_ overlay: CatEventOverlay) -> (pixels: [[Bool]], color: Color) {
        switch overlay {
        case .toolDone:
            return ([
                [false, false, true],
                [false, true,  true],
                [true,  true,  false],
            ], .green)
        case .approvalNeeded:
            return ([
                [false, true, false],
                [false, true, false],
                [false, false, false],
                [false, true, false],
            ], .orange)
        case .errorOccurred:
            return ([
                [true,  false, true],
                [false, true,  false],
                [true,  false, true],
            ], .red)
        case .sessionComplete:
            return ([
                [false, true, false],
                [true,  true, true],
                [false, true, false],
            ], .cyan)
        case .heartPet:
            return ([
                [true,  false, true],
                [true,  true,  true],
                [false, true,  false],
            ], .pink)
        }
    }
}
