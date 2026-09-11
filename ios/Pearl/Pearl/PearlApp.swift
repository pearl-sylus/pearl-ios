import SwiftUI

@main
struct PearlApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color(red: 0.78, green: 0.19, blue: 0.16))
        }
    }
}

private struct RootView: View {
    var body: some View {
        WebHomeView(url: ChatAPI.baseURL)
    }
}
