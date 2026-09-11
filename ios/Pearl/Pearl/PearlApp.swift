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
    @StateObject private var health = HealthProbeModel()
    @State private var isShowingHealthProbe = true

    var body: some View {
        WebHomeView(url: ChatAPI.baseURL)
            .sheet(isPresented: $isShowingHealthProbe) {
                HealthProbeView(model: health)
            }
    }
}
