
import SwiftUI

struct SettingsPageScrollView<Content: View>: View {
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 5)
        }
    }
}
