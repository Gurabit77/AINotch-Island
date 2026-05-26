import SwiftUI

struct CircularProgressRing: View {
    let progress: Double
    let isSpinning: Bool
    let color: Color
    let innerIcon: String
    var state: RingState = .active

    enum RingState: Equatable {
        case idle
        case active
        case pulsing
        case completed
    }

    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var completionTrim: CGFloat = 0
    @State private var showCheckmark: Bool = false

    private let ringSize: CGFloat = 24
    private let lineWidth: CGFloat = 2.5
    private let iconSize: CGFloat = 10

    var body: some View {
        ZStack {
            backgroundTrack
            progressArc
            centerIcon
        }
        .frame(width: ringSize, height: ringSize)
        .scaleEffect(pulseScale)
        .onChange(of: state) { _, newState in
            handleStateChange(newState)
        }
        .onAppear {
            handleStateChange(state)
        }
    }

    private var backgroundTrack: some View {
        Circle()
            .stroke(color.opacity(0.15), lineWidth: lineWidth)
    }

    @ViewBuilder
    private var progressArc: some View {
        switch state {
        case .idle:
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

        case .active:
            Circle()
                .trim(from: 0, to: isSpinning ? 0.7 : progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(isSpinning ? rotationAngle : -90))
                .animation(
                    isSpinning ? .linear(duration: 2).repeatForever(autoreverses: false) : .easeInOut(duration: 0.5),
                    value: isSpinning ? rotationAngle : progress
                )
                .onAppear {
                    if isSpinning { rotationAngle = 360 }
                }
                .onChange(of: isSpinning) { _, spinning in
                    if spinning {
                        rotationAngle = 0
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                }

        case .pulsing:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                    }
                }

        case .completed:
            Circle()
                .trim(from: 0, to: completionTrim)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    @ViewBuilder
    private var centerIcon: some View {
        if state == .completed && showCheckmark {
            CheckmarkAnimation(color: color)
                .frame(width: iconSize, height: iconSize)
        } else {
            Image(systemName: innerIcon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(color.opacity(state == .idle ? 0.4 : 0.8))
        }
    }

    private func handleStateChange(_ newState: RingState) {
        pulseScale = 1.0
        showCheckmark = false

        switch newState {
        case .idle:
            withAnimation(.easeInOut(duration: 0.3)) {
                rotationAngle = 0
            }

        case .active:
            if isSpinning {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }

        case .pulsing:
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }

        case .completed:
            withAnimation(.easeOut(duration: 0.5)) {
                completionTrim = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showCheckmark = true
                }
            }
        }
    }
}
