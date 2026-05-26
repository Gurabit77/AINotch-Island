
import SwiftUI

struct FileConverterNotchView: View {
    @ObservedObject var airDropViewModel: AirDropNotchViewModel
    let targetColorStyle: DragAndDropTargetColorStyle

    var body: some View {
        DragAndDropDropZoneView(
            target: .fileConverter,
            isTargeted: airDropViewModel.targetedDropTarget == .fileConverter,
            targetColorStyle: targetColorStyle
        )
    }
}
