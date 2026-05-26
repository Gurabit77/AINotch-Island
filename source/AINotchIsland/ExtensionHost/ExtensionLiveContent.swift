import SwiftUI

struct ExtensionLiveContent: NotchContentProtocol {
    let id: String
    let stackID: String
    let manifest: ExtensionManifest
    let extensionManager: ExtensionManager

    var priority: Int { 7 }
    var strokeColor: Color { parseStrokeColor() }
    var isExpandable: Bool { manifest.notchConfig?.expandable ?? false }
    var expandsOnTap: Bool { isExpandable }
    var windowLink: (@MainActor () -> Void)? { nil }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let w = manifest.notchConfig?.compactWidth ?? 80
        return CGSize(width: baseWidth + w, height: baseHeight)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let w = manifest.notchConfig?.expandedWidth ?? 200
        let h = manifest.notchConfig?.expandedHeight ?? 200
        return CGSize(width: max(baseWidth + w, 300), height: h)
    }

    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: baseRadius, bottom: baseRadius)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: baseRadius, bottom: baseRadius)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(ExtensionCompactWrapperView(extensionId: manifest.id, manager: extensionManager))
    }

    @MainActor
    func makeExpandedView() -> AnyView {
        AnyView(ExtensionExpandedWrapperView(extensionId: manifest.id, manager: extensionManager))
    }

    private func parseStrokeColor() -> Color {
        guard let colorName = manifest.notchConfig?.strokeColor else { return .white.opacity(0.3) }
        switch colorName {
        case "green": return .green.opacity(0.5)
        case "blue": return .blue.opacity(0.5)
        case "orange": return .orange.opacity(0.5)
        case "red": return .red.opacity(0.5)
        case "purple": return .purple.opacity(0.5)
        default: return .white.opacity(0.3)
        }
    }
}

private struct ExtensionCompactWrapperView: View {
    let extensionId: String
    @ObservedObject var manager: ExtensionManager

    var body: some View {
        if let node = manager.extensionViews[extensionId] {
            ExtensionRendererView(node: node)
        } else {
            Text("...")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct ExtensionExpandedWrapperView: View {
    let extensionId: String
    @ObservedObject var manager: ExtensionManager

    var body: some View {
        if let node = manager.extensionViews[extensionId] {
            ExtensionRendererView(node: node)
                .padding()
        } else {
            VStack {
                ProgressView()
                Text("Loading extension...")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
