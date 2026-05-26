
import SwiftUI

struct ScreenRecordingView: View {
    @Environment(\.notchScale) private var scale
    @State private var isBlinking = false

    var body: some View {
        HStack {
            CrabReactionView(scene: .screenRecording, pixelSize: 3.0)
                .scaleEffect(0.75)
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(isBlinking ? 0.5 : 1)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16.scaled(by: scale))
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
        .onDisappear {
            isBlinking = false
        }
    }
}
