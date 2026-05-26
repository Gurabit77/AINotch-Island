
import SwiftUI

struct HotspotActiveNotchView: View {
    @Environment(\.notchScale) var scale
    let style: HotspotAppearanceStyle
    
    var body: some View {
        HStack(spacing: 0) {
            CrabReactionView(scene: .hotspotActive, pixelSize: 3.0)
                .scaleEffect(0.75)
                .padding(.trailing, 6)
            if style == .minimal {
                Image(systemName: "personalhotspot")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.green)

                Spacer()

            } else {
                Image(systemName: "personalhotspot")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.green)

                Spacer(minLength: 10)

                Text(L10n.app("notch.hotspot.on", fallback: "On"))
                    .font(.system(size: 14))
                    .foregroundStyle(.green.opacity(0.8))
            }
        }
        .padding(.horizontal, 14.scaled(by: scale))
    }
}
