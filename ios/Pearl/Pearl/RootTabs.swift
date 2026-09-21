import SwiftUI
import WebKit

struct RootTabs: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var health = HealthProbeModel()

    var body: some View {
        TabView {
            ChatView(health: health)
                .tabItem { Label("说话", systemImage: "bubble.left.and.bubble.right") }
            HomeWebView(url: ChatAPI.baseURL)
                .tabItem { Label("家", systemImage: "house") }
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
