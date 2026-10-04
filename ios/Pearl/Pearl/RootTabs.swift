import SwiftUI
import WebKit

struct RootTabs: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var health = HealthProbeModel()

    @State private var tab = 1

    var body: some View {
        TabView(selection: $tab) {
            // 10.5 她要的:首页和日子回到原生(9.13 的版本找回),网页版留一格进冰箱门/通话记录/设置
            HomeView { tab = 1 }
                .tabItem { Label("家", systemImage: "house") }
                .tag(0)
            ChatView(health: health)
                .tabItem { Label("说话", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)
            DaysView()
                .tabItem { Label("日子", systemImage: "calendar") }
                .tag(2)
            HomeWebView(url: ChatAPI.baseURL)
                .tabItem { Label("更多", systemImage: "square.grid.2x2") }
                .tag(3)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await health.syncIfEnabled() }
        }
    }
}

private struct HomeWebView: View {
    let url: URL

    var body: some View {
        SiteWebView(url: url).ignoresSafeArea(edges: .top)
    }
}

private struct SiteWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
    }
}
