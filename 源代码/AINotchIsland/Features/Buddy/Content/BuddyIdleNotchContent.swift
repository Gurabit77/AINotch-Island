import SwiftUI

struct BuddyIdleNotchContent: NotchContentProtocol {
    let id = NotchContentRegistry.Buddy.idle.id

    var priority: Int { NotchContentRegistry.Buddy.idle.priority }
    var isExpandable: Bool { false }

    let scene: CrabScene

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 40, height: baseHeight + 4)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(BuddyIdleNotchView(scene: scene))
    }
}

struct BuddyIdleNotchView: View {
    let scene: CrabScene

    var body: some View {
        HStack {
            CrabReactionView(scene: scene, pixelSize: 3.0)
                .scaleEffect(0.75)
            Spacer()
        }
        .padding(.horizontal, 10)
    }
}
