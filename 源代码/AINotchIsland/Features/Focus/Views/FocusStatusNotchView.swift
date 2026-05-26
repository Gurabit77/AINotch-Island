
import SwiftUI

struct FocusOnNotchView: View {
    let style: FocusAppearanceStyle

    var body: some View {
        HStack(spacing: 6) {
            CrabReactionView(scene: .focusOn, pixelSize: 3.0)
                .scaleEffect(0.75)
            FocusStatusNotchView(title: L10n.app("notch.focus.on", fallback: "On"), tint: .indigo, style: style)
        }
        .padding(.leading, 14)
    }
}

struct FocusOffNotchView: View {
    let style: FocusAppearanceStyle

    var body: some View {
        HStack(spacing: 6) {
            CrabReactionView(scene: .focusOff, pixelSize: 3.0)
                .scaleEffect(0.75)
            FocusStatusNotchView(title: L10n.app("notch.focus.off", fallback: "Off"), tint: .gray.opacity(0.6), style: style)
        }
        .padding(.leading, 14)
    }
}

private struct FocusStatusNotchView: View {
    @Environment(\.notchScale) var scale

    let title: String
    let tint: Color
    let style: FocusAppearanceStyle

    var body: some View {
        Group {
            if style == .iconsOnly {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 16, weight: .bold))

                    Spacer(minLength: 0)
                }
            } else {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 16, weight: .bold))

                    Spacer()

                    Text(verbatim: title)
                }
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14.scaled(by: scale))
    }
}
