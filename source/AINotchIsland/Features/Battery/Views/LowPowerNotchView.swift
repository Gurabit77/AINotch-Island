
import SwiftUI

struct LowPowerNotchView: View {
    @ObservedObject var powerService: PowerService
    let style: BatteryNotificationStyle

    @State private var pulse = false

    private var batteryColor: Color {
        powerService.isLowPowerMode ? .yellow : .red
    }

    private func startPulse() {
        pulse = false
        withAnimation(
            .easeInOut(duration: 1)
            .repeatForever(autoreverses: true)
        ) {
            pulse = true
        }
    }

    var body: some View {
        Group {
            if style == .compact {
                HStack(spacing: 8) {
                    CrabReactionView(scene: .lowBattery, pixelSize: 3.0)
                        .scaleEffect(0.75)
                    BatteryCompactStatusView(
                        title: L10n.app("notch.battery.lowBattery", fallback: "Low Battery"),
                        batteryLevel: powerService.batteryLevel,
                        tint: batteryColor
                    )
                }
                .padding(.leading, 14)
            } else {
                VStack {
                    Spacer()

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            title
                            description
                        }

                        Spacer()

                        if powerService.isLowPowerMode {
                            yellowIndicator
                        } else {
                            redIndicator
                        }
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 45)
            }
        }
    }

    @ViewBuilder
    private var title: some View {
        HStack {
            Text(L10n.app("notch.battery.batteryLow", fallback: "Battery Low"))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .fontWeight(.semibold)
                .lineLimit(1)

            Text("\(powerService.batteryLevel)%")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundStyle(batteryColor)
        }
    }

    @ViewBuilder
    private var description: some View {
        if powerService.isLowPowerMode {
            Text(L10n.app("notch.battery.lowPowerEnabled", fallback: "Low Power Mode enabled"))
                .foregroundColor(.yellow)
                .font(.system(size: 10, weight: .medium))

            + Text(L10n.app("notch.battery.recommendCharge", fallback: ", it is recommended to charge it."))
                .foregroundColor(.gray.opacity(0.6))
                .font(.system(size: 10, weight: .medium))
        } else {
            Text(L10n.app("notch.battery.turnOnLowPower", fallback: "Turn on Low Power Mode or it \nis recommended to charge it."))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray.opacity(0.6))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var redIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(.red.opacity(0.2))
                .frame(width: 70, height: 40)

            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.red.opacity(0.4))
                    .frame(width: 40, height: 24)

                RoundedRectangle(cornerRadius: 10)
                    .fill(.red.opacity(0.4))
                    .frame(width: 3, height: 8)
            }
            .padding(.trailing, 5)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.gradient)
                .frame(width: 8, height: 14)
                .opacity(pulse ? 1 : 0.3)
                .offset(x: -15)
                .onAppear { startPulse() }

            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.red.opacity(0.9).gradient, lineWidth: 1.5)
                .frame(width: pulse ? 8 : 30, height: pulse ? 14 : 32)
                .offset(x: -15)
                .opacity(pulse ? 0.3 : 1)
        }
    }

    @ViewBuilder
    private var yellowIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(.yellow.opacity(0.2))
                .frame(width: 70, height: 40)

            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.yellow.opacity(0.4))
                    .frame(width: 40, height: 24)

                RoundedRectangle(cornerRadius: 10)
                    .fill(.yellow.opacity(0.4))
                    .frame(width: 3, height: 8)
            }
            .padding(.trailing, 5)

            RoundedRectangle(cornerRadius: 8)
                .fill(.yellow.gradient)
                .frame(width: 8, height: 14)
                .offset(x: -15)
        }
    }
}
