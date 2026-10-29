import SwiftUI

@main
struct PearlApp: App {
    @UIApplicationDelegateAdaptor(PearlAppDelegate.self) private var appDelegate   // 10.30 一启动就登记 VoIP 推送
    @StateObject private var theme = Theme()
    @StateObject private var calls = CallCoordinator.shared

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environmentObject(theme)
                .environmentObject(calls)
                .tint(theme.accent)
                // 10.5 原生电话:推送点开 pearlden://call?id=… 直接进通话页;她自己拨也走这里
                .onOpenURL { url in _ = calls.open(url: url) }
                .fullScreenCover(item: $calls.active) { handle in
                    CallView(model: calls.viewModel(for: handle)) { calls.close() }
                        .environmentObject(theme)
                }
                .alert("系统来电测试", isPresented: Binding(get: { calls.notice != nil }, set: { if !$0 { calls.notice = nil } })) {
                    Button("知道了", role: .cancel) { calls.notice = nil }
                } message: {
                    Text(calls.notice ?? "")
                }
        }
    }
}
