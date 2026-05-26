import SwiftUI

struct HudContentView: View {
    @Environment(\.notchScale) var scale
    
    let image: String
    let text: String
    let level: Int
    let style: HudStyle
    let indicatorStyle: HudIndicatorStyle
    let indicatorTintStyle: HudIndicatorTintStyle
    let showsIndicatorGlow: Bool
    
    private var barIndicatorWidth: CGFloat {
        switch style {
        case .standard:
            return 50
        case .compact:
            return 50
        case .minimal:
            return 60
        }
    }
    
    private var barIndicatorHeight: CGFloat { 6 }
    
    private var circleIndicatorSize: CGFloat {
        switch style {
        case .standard:
            return 19
        case .compact:
            return 19
        case .minimal:
            return 19
        }
    }

    private var circleIndicatorLineWidth: CGFloat {
        switch style {
        case .standard, .compact:
            return 3
        case .minimal:
            return 3.5
        }
    }

    private var clampedLevel: Int { max(0, min(100, level)) }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .standard:
            return 16
        case .compact:
            return 14
        case .minimal:
            return 14
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            switch style {
            case .standard:
                CrabReactionView(scene: hudCrabScene, pixelSize: 3.0)
                    .scaleEffect(0.75)
                Text(verbatim: text)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))

                Spacer(minLength: 12)

                indicator

            case .compact:
                CrabReactionView(scene: hudCrabScene, pixelSize: 3.0)
                    .scaleEffect(0.75)
                icon
                Spacer()
                indicator

            case .minimal:
                CrabReactionView(scene: hudCrabScene, pixelSize: 2.0)
                    .scaleEffect(0.65)
                icon
                Spacer()
                AnimatedLevelText(level: clampedLevel, fontSize: 16)

            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, horizontalPadding.scaled(by: scale))
    }

    private var hudCrabScene: CrabScene {
        if image.contains("speaker.slash") || level == 0 {
            return .volumeMute
        } else if image.contains("speaker") {
            return .volumeUp
        } else {
            return .brightnessChange
        }
    }
    
    private var icon: some View {
        Image(systemName: image)
            .font(.system(size: 18))
            .foregroundColor(.white)
    }
    
    @ViewBuilder
    private var indicator: some View {
        HudLevelIndicatorView(
            level: clampedLevel,
            indicatorStyle: indicatorStyle,
            tintStyle: indicatorTintStyle,
            showsGlow: showsIndicatorGlow,
            barWidth: barIndicatorWidth,
            barHeight: barIndicatorHeight,
            circleSize: circleIndicatorSize,
            circleLineWidth: circleIndicatorLineWidth
        )
    }
}
