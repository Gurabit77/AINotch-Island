
import SwiftUI

struct ChargerNotchView: View {
    @ObservedObject var powerService: PowerService
    
    private var batteryColor: Color {
        if powerService.isLowPowerMode {
            return .yellow
        } else if powerService.batteryLevel <= 20 {
            return .red
        } else {
            return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            CrabReactionView(scene: .charging, pixelSize: 3.0)
                .scaleEffect(0.75)
            BatteryCompactStatusView(
                title: L10n.app("notch.battery.charging", fallback: "Charging"),
                batteryLevel: powerService.batteryLevel,
                tint: batteryColor
            )
        }
        .padding(.leading, 14)
    }
}
