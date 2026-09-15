import SwiftUI

@main
struct PearlApp: App {
    @StateObject private var theme = Theme()

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environmentObject(theme)
                .tint(theme.accent)
        }
    }
}
