import SwiftUI

struct ExternalDriveNotchContent: NotchContentProtocol {
    let id: String
    let driveName: String
    let isEjecting: Bool

    var priority: Int { NotchContentRegistry.ExternalDrive.connected.priority }
    var isExpandable: Bool { false }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 140, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(ExternalDriveNotchView(driveName: driveName, isEjecting: isEjecting))
    }
}
