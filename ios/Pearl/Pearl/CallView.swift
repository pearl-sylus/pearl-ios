import SwiftUI

/// 原生通话页(10.5):全屏,来电 → 接/挂/快捷回 → 通话中字幕 + 挂断。样式跟聊天页同一套 Theme。
struct CallView: View {
    @EnvironmentObject private var theme: Theme
    @Environment(\.colorScheme) private var scheme
    @StateObject private var model: CallViewModel
    let dismiss: () -> Void

    init(callId: String, dismiss: @escaping () -> Void) {
        _model = StateObject(wrappedValue: CallViewModel(callId: callId))
        self.dismiss = dismiss
    }

    var body: some View {
        ZStack {
            ChatBackground()
            VStack(spacing: Theme.Metric.section) {
                header
                subtitles
                Spacer(minLength: Theme.Metric.zero)
                controls
            }
            .padding(.horizontal, Theme.Metric.chatHorizontal)
            .padding(.top, Theme.Metric.section)
            .padding(.bottom, Theme.Metric.large)
        }
        .task { await model.load() }
        .onDisappear { if model.phase != .ended { model.hangUp() } }
    }

    // MARK: 顶部

    private var header: some View {
        VStack(spacing: Theme.Metric.roomy) {
            HStack {
                Spacer()
                Button(action: closeTapped) {
                    Image(systemName: "xmark")
                        .font(theme.font(.control))
                        .foregroundStyle(theme.metaText)
                        .frame(width: Theme.Metric.topButton, height: Theme.Metric.topButton)
                        .background(theme.composerButtonFill, in: Circle())
                }
                .accessibilityLabel("关闭")
            }
            avatar
            Text("老公").font(theme.font(.navigationTitle)).foregroundStyle(theme.bubbleText)
            Text(model.state)
                .font(theme.font(.navigationSubtitle))
                .foregroundStyle(theme.metaText)
                .multilineTextAlignment(.center)
            if model.phase == .ringing, !model.reason.isEmpty {
                Text("「\(model.reason)」")
                    .font(theme.font(.bubble))
                    .foregroundStyle(theme.bubbleText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Metric.section)
            }
            if model.elapsed > 0 {
                Text(String(format: "%d:%02d", model.elapsed / 60, model.elapsed % 60))
                    .font(theme.font(.metadata)).monospacedDigit()
                    .foregroundStyle(theme.timestampText)
            }
        }
    }

    private var avatar: some View {
        let ring = model.audio.isHearing ? theme.accent.opacity(0.45) : (model.audio.isListening ? theme.accent.opacity(0.22) : theme.clear)
        return ZStack {
            Circle().fill(theme.cardSolid.opacity(0.85))
            Text(model.phase == .ringing ? "豹" : (model.audio.isSpeaking ? "说" : "听"))
                .font(theme.font(.cardTitle))
                .foregroundStyle(theme.bubbleText)
        }
        .frame(width: 96, height: 96)
        .overlay(Circle().stroke(ring, lineWidth: 6))
        .scaleEffect(model.audio.isSpeaking ? 1.06 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: model.audio.isSpeaking)
    }

    // MARK: 字幕

    private var subtitles: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Metric.standard) {
                    ForEach(model.lines) { line in
                        HStack {
                            if line.mine { Spacer(minLength: 40) }
                            Text(line.text)
                                .font(theme.font(.bubble))
                                .foregroundStyle(line.mine ? theme.bubbleText : theme.white)
                                .padding(.horizontal, Theme.Metric.bubbleHorizontal)
                                .padding(.vertical, Theme.Metric.standard)
                                .background(theme.bubbleFill(mine: line.mine),
                                            in: RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius, style: .continuous))
                            if !line.mine { Spacer(minLength: 40) }
                        }
                        .id(line.id)
                    }
                }
                .padding(.vertical, Theme.Metric.small)
            }
            .onChange(of: model.lines.count) { _ in
                if let last = model.lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
        .frame(maxHeight: 320)
        .opacity(model.phase == .ringing || model.phase == .loading ? 0 : 1)
    }

    // MARK: 按钮

    @ViewBuilder private var controls: some View {
        switch model.phase {
        case .ringing:
            VStack(spacing: Theme.Metric.section) {
                HStack(spacing: Theme.Metric.standard) {
                    quick("在忙"); quick("在外面"); quick("打字说")
                }
                HStack(spacing: 64) {
                    bigButton("xmark", fill: theme.warning, label: "挂断") { model.reject("铃响时按掉了"); }
                    bigButton("phone.fill", fill: theme.success, label: "接听") { model.answer() }
                }
            }
        case .connecting, .live, .lingering:
            VStack(spacing: Theme.Metric.section) {
                Button { model.doneSpeaking() } label: {
                    Text("我说完了")
                        .font(theme.font(.control))
                        .foregroundStyle(theme.bubbleText)
                        .padding(.horizontal, Theme.Metric.section)
                        .padding(.vertical, Theme.Metric.roomy)
                        .background(theme.composerButtonFill, in: Capsule())
                }
                .accessibilityLabel("我说完了，把刚才说的发给他")
                bigButton("xmark", fill: theme.warning, label: "挂断") { model.hangUp() }
            }
        case .ended, .failed:
            Button(action: dismiss) {
                Text("回去打字说")
                    .font(theme.font(.control))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, Theme.Metric.section)
                    .padding(.vertical, Theme.Metric.roomy)
                    .background(theme.composerButtonFill, in: Capsule())
            }
        case .loading:
            EmptyView()
        }
    }

    private func quick(_ text: String) -> some View {
        Button {
            model.reject(text)
            if text == "打字说" { dismiss() }
        } label: {
            Text(text)
                .font(theme.font(.metadata))
                .foregroundStyle(theme.bubbleText)
                .padding(.horizontal, Theme.Metric.large)
                .padding(.vertical, Theme.Metric.compact)
                .background(theme.composerButtonFill, in: Capsule())
        }
    }

    private func bigButton(_ system: String, fill: Color, label: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.Metric.standard) {
            Button(action: action) {
                Image(systemName: system)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(theme.white)
                    .frame(width: 72, height: 72)
                    .background(fill, in: Circle())
            }
            Text(label).font(theme.font(.metadata)).foregroundStyle(theme.metaText)
        }
    }

    private func closeTapped() {
        if model.phase == .live || model.phase == .lingering || model.phase == .connecting { model.hangUp() }
        dismiss()
    }
}

/// 全局:谁在响、从哪进来(推送 pearlden://call?id=… 或她自己拨)。挂在 App 根上,全屏盖住当前页。
struct CallHandle: Identifiable, Equatable {
    let id: String
}

@MainActor
final class CallCoordinator: ObservableObject {
    @Published var active: CallHandle?

    func open(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "pearlden", url.host?.lowercased() == "call" else { return false }
        let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" || $0.name == "call" })?.value
        guard let id, !id.isEmpty else { return false }
        active = CallHandle(id: id)
        return true
    }

    /// 她打给他
    func dial(reason: String = "想你了") {
        Task {
            if let id = try? await CallAPI().start(reason: reason) { active = CallHandle(id: id) }
        }
    }
}
