
import SwiftUI

struct WifiConnectedNotchContent: NotchContentProtocol {
    let id = NotchContentRegistry.Network.wifi.id
    var priority: Int { NotchContentRegistry.Network.wifi.priority }
    
    let networkViewModel: NetworkViewModel
    
    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 110, height: baseHeight)
    }
    
    @MainActor
    func makeView() -> AnyView {
        AnyView(
            WifiConnectedNotchView(
                networkViewModel: networkViewModel
            )
        )
    }
}
