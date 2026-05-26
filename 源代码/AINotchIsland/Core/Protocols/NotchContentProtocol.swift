
import SwiftUI

protocol NotchContentProtocol {
    var id: String { get }
    var stackID: String { get }
    var priority: Int { get }
    var strokeColor: Color { get }
    var isExpandable: Bool { get }
    var expandsOnTap: Bool { get }
    var windowLink: (@MainActor () -> Void)? { get }
    var preventsAutoCollapse: Bool { get }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat)
    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat)
    
    @MainActor @ViewBuilder func makeView() -> AnyView
    @MainActor @ViewBuilder func makeExpandedView() -> AnyView

    @MainActor func handleTap(at point: CGPoint, in bounds: CGSize) -> Bool
}

extension NotchContentProtocol {
    var stackID: String { id }
    var priority: Int { NotchContentPriority.default }
    var strokeColor: Color { .white.opacity(0.2) }
    var isExpandable: Bool { false }
    var expandsOnTap: Bool { isExpandable }
    var windowLink: (@MainActor () -> Void)? { nil }
    var preventsAutoCollapse: Bool { false }
    
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        return (top: baseRadius - 4, bottom: baseRadius)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        size(baseWidth: baseWidth, baseHeight: baseHeight)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        cornerRadius(baseRadius: baseRadius)
    }

    @MainActor
    func makeExpandedView() -> AnyView {
        makeView()
    }

    @MainActor
    func handleTap(at point: CGPoint, in bounds: CGSize) -> Bool {
        false
    }
}
