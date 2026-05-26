import SwiftUI

struct GradientStrokeModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

extension View {
    func gradientStroke(color: Color, cornerRadius: CGFloat = 14, lineWidth: CGFloat = 1.5) -> some View {
        modifier(GradientStrokeModifier(color: color, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}
