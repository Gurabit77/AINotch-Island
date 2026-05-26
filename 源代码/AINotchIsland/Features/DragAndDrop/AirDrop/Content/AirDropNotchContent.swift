
import SwiftUI

enum AirDropEvent: Equatable {
    case dragStarted
    case dragEnded
    case dropped
}

struct AirDropNotchContent: NotchContentProtocol {
    let id = NotchContentRegistry.DragAndDrop.airDrop.id
    
    let airDropViewModel: AirDropNotchViewModel
    let settingsViewModel: SettingsViewModel

    var priority: Int { NotchContentRegistry.DragAndDrop.airDrop.priority }

    var strokeColor: Color {
        settingsViewModel.isDefaultActivityStrokeEnabled || settingsViewModel.mediaAndFiles.isDragAndDropDefaultStrokeEnabled ?
        .white.opacity(0.2) :
        DragAndDropTarget.airDrop.activityStrokeColor(for: settingsViewModel.mediaAndFiles.dragAndDropTargetColorStyle)
    }
    
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        return (top: 24, bottom: 36)
    }
    
    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        return .init(width: baseWidth + 40, height: baseHeight + 110)
    }
    
    @MainActor
    func makeView() -> AnyView {
        AnyView(
            AirDropNotchView(
                airDropViewModel: airDropViewModel,
                targetColorStyle: settingsViewModel.mediaAndFiles.dragAndDropTargetColorStyle
            )
        )
    }
}
