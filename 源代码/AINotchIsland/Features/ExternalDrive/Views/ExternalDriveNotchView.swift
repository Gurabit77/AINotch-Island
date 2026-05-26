import SwiftUI

struct ExternalDriveNotchView: View {
    @Environment(\.notchScale) private var scale
    let driveName: String
    let isEjecting: Bool

    var body: some View {
        HStack(spacing: 8) {
            CrabReactionView(scene: isEjecting ? .usbEjected : .usbConnected, pixelSize: 3.0)
                .scaleEffect(0.75)

            Image(systemName: isEjecting ? "eject.fill" : "externaldrive.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEjecting ? .orange : .green)

            Spacer()

            Text(driveName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14.scaled(by: scale))
    }
}
