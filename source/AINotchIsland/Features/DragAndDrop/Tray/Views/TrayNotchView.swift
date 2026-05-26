
import SwiftUI

struct TrayNotchView: View {
    @ObservedObject var airDropViewModel: AirDropNotchViewModel
    let targetColorStyle: DragAndDropTargetColorStyle

    var body: some View {
        DragAndDropDropZoneView(
            target: .tray,
            isTargeted: airDropViewModel.targetedDropTarget == .tray,
            targetColorStyle: targetColorStyle
        )
    }
}
