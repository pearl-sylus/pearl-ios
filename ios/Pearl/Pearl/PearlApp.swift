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
        TabView {
            ChatView()
                .tabItem { Label("说话", systemImage: "bubble.left.and.bubble.right.fill") }

            WebHomeView(url: ChatAPI.baseURL)
                .tabItem { Label("家", systemImage: "house.fill") }
        }
    }
}
