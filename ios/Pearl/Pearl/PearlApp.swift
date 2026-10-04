import SwiftUI

@main
struct PearlApp: App {
    @StateObject private var theme = Theme()
    @StateObject private var calls = CallCoordinator()

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environmentObject(theme)
                .environmentObject(calls)
                .tint(theme.accent)
                // 10.5 原生电话:推送点开 pearlden://call?id=… 直接进通话页;她自己拨也走这里
                .onOpenURL { url in _ = calls.open(url: url) }
                .fullScreenCover(item: $calls.active) { handle in
                    CallView(callId: handle.id) { calls.active = nil }
                        .environmentObject(theme)
                }
        }
    }
}
