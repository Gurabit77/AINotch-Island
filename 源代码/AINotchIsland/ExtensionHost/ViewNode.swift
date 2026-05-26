import SwiftUI

indirect enum ViewNode: Equatable {
    case text(String, ViewNodeStyle)
    case image(systemName: String, ViewNodeStyle)
    case hstack([ViewNode], spacing: CGFloat?, ViewNodeStyle)
    case vstack([ViewNode], spacing: CGFloat?, ViewNodeStyle)
    case zstack([ViewNode], ViewNodeStyle)
    case spacer(minLength: CGFloat?)
    case divider
    case progress(value: Double, total: Double, ViewNodeStyle)
    case capsule(child: ViewNode, ViewNodeStyle)
    case empty
}

struct ViewNodeStyle: Equatable {
    var fontSize: CGFloat?
    var fontWeight: String?
    var fontDesign: String?
    var foregroundColor: String?
    var backgroundColor: String?
    var opacity: CGFloat?
    var padding: CGFloat?
    var paddingEdges: String?
    var cornerRadius: CGFloat?
    var frame: ViewNodeFrame?
    var lineLimit: Int?

    static let empty = ViewNodeStyle()
}

struct ViewNodeFrame: Equatable {
    var width: CGFloat?
    var height: CGFloat?
    var maxWidth: CGFloat?
    var maxHeight: CGFloat?
    var alignment: String?
}
