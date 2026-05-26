import SwiftUI
internal import AppKit

struct AppKitClickableView: NSViewRepresentable {
    let onClick: () -> Void

    func makeNSView(context: Context) -> ClickTargetNSView {
        let view = ClickTargetNSView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: ClickTargetNSView, context: Context) {
        nsView.onClick = onClick
    }
}

final class ClickTargetNSView: NSView {
    var onClick: (() -> Void)?
    private var isMouseDown = false

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if bounds.contains(local) {
            return self
        }
        return nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        isMouseDown = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isMouseDown else { return }
        isMouseDown = false

        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onClick?()
        }
    }
}
