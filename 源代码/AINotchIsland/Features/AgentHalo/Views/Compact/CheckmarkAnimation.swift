import SwiftUI

struct CheckmarkAnimation: View {
    var color: Color = .green
    @State private var trimEnd: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: w * 0.2, y: h * 0.55))
                path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.75))
                path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.3))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                trimEnd = 1.0
            }
        }
    }
}
