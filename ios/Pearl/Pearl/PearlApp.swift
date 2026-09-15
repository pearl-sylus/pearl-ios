import SwiftUI

@main
struct PearlApp: App {
    @StateObject private var theme = Theme()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .tint(theme.accent)
        }
    }
}

private struct RootView: View {
    var body: some View {
        ChatView()
    }
}
