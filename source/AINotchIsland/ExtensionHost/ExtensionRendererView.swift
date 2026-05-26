import SwiftUI

struct ExtensionRendererView: View {
    let node: ViewNode

    var body: some View {
        renderNode(node)
    }

    @ViewBuilder
    private func renderNode(_ node: ViewNode) -> some View {
        switch node {
        case .text(let content, let style):
            applyStyle(Text(content), style: style)

        case .image(let systemName, let style):
            applyImageStyle(Image(systemName: systemName), style: style)

        case .hstack(let children, let spacing, let style):
            applyContainerStyle(style) {
                HStack(spacing: spacing) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        renderNode(child)
                    }
                }
            }

        case .vstack(let children, let spacing, let style):
            applyContainerStyle(style) {
                VStack(spacing: spacing) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        renderNode(child)
                    }
                }
            }

        case .zstack(let children, let style):
            applyContainerStyle(style) {
                ZStack {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        renderNode(child)
                    }
                }
            }

        case .spacer(let minLength):
            Spacer(minLength: minLength)

        case .divider:
            Divider()

        case .progress(let value, let total, let style):
            applyContainerStyle(style) {
                ProgressView(value: value, total: total)
                    .progressViewStyle(.linear)
            }

        case .capsule(let child, let style):
            applyContainerStyle(style) {
                renderNode(child)
                    .clipShape(Capsule())
            }

        case .empty:
            EmptyView()
        }
    }

    @ViewBuilder
    private func applyStyle(_ text: Text, style: ViewNodeStyle) -> some View {
        let sized = style.fontSize != nil
            ? text.font(.system(size: style.fontSize!, weight: fontWeight(style.fontWeight), design: fontDesign(style.fontDesign)))
            : text.font(.system(size: 12, weight: fontWeight(style.fontWeight), design: fontDesign(style.fontDesign)))

        let colored = style.foregroundColor != nil
            ? sized.foregroundStyle(parseColor(style.foregroundColor!))
            : sized.foregroundStyle(.white)

        let limited = style.lineLimit != nil
            ? colored.lineLimit(style.lineLimit)
            : colored.lineLimit(nil)

        if let padding = style.padding {
            limited.padding(padding)
        } else {
            limited
        }
    }

    @ViewBuilder
    private func applyImageStyle(_ image: Image, style: ViewNodeStyle) -> some View {
        let sized: AnyView = style.fontSize != nil
            ? AnyView(image.font(.system(size: style.fontSize!)))
            : AnyView(image)

        let colored: AnyView = style.foregroundColor != nil
            ? AnyView(sized.foregroundStyle(parseColor(style.foregroundColor!)))
            : AnyView(sized.foregroundStyle(.white))

        if let opacity = style.opacity {
            colored.opacity(opacity)
        } else {
            colored
        }
    }

    @ViewBuilder
    private func applyContainerStyle<Content: View>(_ style: ViewNodeStyle, @ViewBuilder content: () -> Content) -> some View {
        let base = content()

        let padded: some View = style.padding != nil
            ? AnyView(base.padding(style.padding!))
            : AnyView(base)

        let framed: some View = {
            if let f = style.frame {
                if f.maxWidth != nil || f.maxHeight != nil {
                    return AnyView(padded.frame(maxWidth: f.maxWidth, maxHeight: f.maxHeight))
                } else if f.width != nil || f.height != nil {
                    return AnyView(padded.frame(width: f.width, height: f.height))
                }
            }
            return AnyView(padded)
        }()

        let bg: some View = style.backgroundColor != nil
            ? AnyView(framed.background(parseColor(style.backgroundColor!)))
            : AnyView(framed)

        let rounded: some View = style.cornerRadius != nil
            ? AnyView(bg.clipShape(RoundedRectangle(cornerRadius: style.cornerRadius!)))
            : AnyView(bg)

        if let opacity = style.opacity {
            rounded.opacity(opacity)
        } else {
            rounded
        }
    }

    private func fontWeight(_ name: String?) -> Font.Weight {
        switch name {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        case "heavy": return .heavy
        default: return .regular
        }
    }

    private func fontDesign(_ name: String?) -> Font.Design {
        switch name {
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
        }
    }

    private func parseColor(_ name: String) -> Color {
        switch name {
        case "white": return .white
        case "black": return .black
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        case "clear": return .clear
        default:
            if name.hasPrefix("#"), name.count == 7 {
                let hex = String(name.dropFirst())
                let scanner = Scanner(string: hex)
                var rgb: UInt64 = 0
                scanner.scanHexInt64(&rgb)
                return Color(
                    red: Double((rgb >> 16) & 0xFF) / 255.0,
                    green: Double((rgb >> 8) & 0xFF) / 255.0,
                    blue: Double(rgb & 0xFF) / 255.0
                )
            }
            return .white
        }
    }
}
