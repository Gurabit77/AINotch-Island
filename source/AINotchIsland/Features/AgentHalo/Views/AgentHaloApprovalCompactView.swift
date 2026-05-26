import SwiftUI
internal import AppKit

struct AgentHaloApprovalCompactView: View {
    let approval: AgentApprovalRequest
    var onApprove: (() -> Void)?
    var onDeny: (() -> Void)?
    @Environment(\.notchScale) var scale
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 6.scaled(by: scale)) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(riskColor)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseOpacity = 0.4
                    }
                }

            Text(approval.title)
                .font(.system(size: 10.scaled(by: scale), weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: 100, alignment: .leading)

            Spacer(minLength: 2)

            if approval.type != .question {
                HStack(spacing: 4) {
                    buttonVisual(icon: "xmark", color: .red)
                    buttonVisual(icon: "checkmark", color: .green)
                }
            }
        }
        .padding(.horizontal, 14.scaled(by: scale))
        .background(
            ApprovalClickMonitor(
                onApprove: { onApprove?() },
                onDeny: { onDeny?() }
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval: \(approval.title), risk \(approval.riskLevel.rawValue)")
    }

    private func buttonVisual(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 22, height: 18)
            .background(
                Capsule().fill(color.opacity(0.15))
            )
    }

    private var riskColor: Color {
        switch approval.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

private struct ApprovalClickMonitor: NSViewRepresentable {
    let onApprove: () -> Void
    let onDeny: () -> Void

    func makeNSView(context: Context) -> ApprovalClickMonitorView {
        let view = ApprovalClickMonitorView()
        view.onApprove = onApprove
        view.onDeny = onDeny
        return view
    }

    func updateNSView(_ nsView: ApprovalClickMonitorView, context: Context) {
        nsView.onApprove = onApprove
        nsView.onDeny = onDeny
    }

    static func dismantleNSView(_ nsView: ApprovalClickMonitorView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

final class ApprovalClickMonitorView: NSView {
    var onApprove: (() -> Void)?
    var onDeny: (() -> Void)?
    private var clickMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func stopMonitoring() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
    }

    private func startMonitoring() {
        guard clickMonitor == nil else { return }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self, self.window != nil else { return event }

            let windowPoint = event.locationInWindow
            let viewPoint = self.convert(windowPoint, from: nil)
            let parentBounds = self.bounds

            guard parentBounds.width > 0 else { return event }

            let buttonsWidth: CGFloat = 48
            let rightPadding: CGFloat = 14
            let buttonsAreaX = parentBounds.maxX - rightPadding - buttonsWidth
            let buttonsAreaRect = NSRect(
                x: buttonsAreaX,
                y: parentBounds.minY,
                width: buttonsWidth + rightPadding,
                height: parentBounds.height
            )

            guard buttonsAreaRect.contains(viewPoint) else { return event }

            let midX = buttonsAreaX + buttonsWidth / 2
            if viewPoint.x < midX {
                DispatchQueue.main.async { self.onDeny?() }
            } else {
                DispatchQueue.main.async { self.onApprove?() }
            }

            return nil
        }
    }
}
