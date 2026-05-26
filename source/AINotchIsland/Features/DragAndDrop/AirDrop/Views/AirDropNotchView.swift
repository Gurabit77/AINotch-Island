
import SwiftUI

struct AirDropNotchView: View {
    @ObservedObject var airDropViewModel: AirDropNotchViewModel
    let targetColorStyle: DragAndDropTargetColorStyle

    var body: some View {
        DragAndDropDropZoneView(
            target: .airDrop,
            isTargeted: airDropViewModel.targetedDropTarget == .airDrop,
            targetColorStyle: targetColorStyle
        )
        .padding(.leading, 14)
    }
}
