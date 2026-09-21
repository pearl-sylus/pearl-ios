import Foundation
import SwiftUI
import UIKit
import WebKit

struct ChatView: View {
    @EnvironmentObject private var theme: Theme
    @StateObject private var model = ChatViewModel()
    @State private var showHistory = false
    @State private var showControls = false
    @State private var showAppearance = false
    @State private var isAtBottom = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Metric.roomy) {
                        if model.hasMore {
                            HistoryPagingButton(title: "↑ 看更早的") { Task { await model.loadOlder() } }
                        }

                        ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, message in
                            if index == 0 || !Calendar.current.isDate(
                                message.date,
                                inSameDayAs: model.messages[index - 1].date
                            ) {
                                ChatDateDivider(date: message.date)
                            }
                            MessageRow(message: message, model: model)
                                .id(message.id)
                                .padding(.vertical, Theme.Metric.thinLine)
                                .modifier(SearchHighlight(active: model.highlightedID == message.id))
                        }

                        if model.isStreaming || !model.liveText.isEmpty || !model.liveThinking.isEmpty {
                            LiveMessageRow(model: model).id("live-message")
                        }

                        if model.hasNewer {
                            HistoryPagingButton(title: "↓ 回到现在") { Task { await model.goLatest() } }
                        }

                        theme.clear
                            .frame(height: Theme.Metric.thinLine)
                            .id("chat-bottom")
                            .onAppear { isAtBottom = true }
                            .onDisappear { isAtBottom = false }
                    }
                    .padding(.horizontal, Theme.Metric.chatHorizontal)
                    .padding(.top, Theme.Metric.roomy)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(ChatBackground())
                .overlay(alignment: .bottomTrailing) {
                    if !isAtBottom {
                        Button {
                            if model.hasNewer {
                                Task { await model.goLatest() }
                            } else {
                                scrollToBottom(proxy)
                            }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(theme.font(.control).weight(.semibold))
                                .frame(width: Theme.Metric.sendButtonSize, height: Theme.Metric.sendButtonSize)
                                .background(theme.panelFill(), in: Circle())
                                .overlay { Circle().stroke(theme.rim(for: .light), lineWidth: Theme.Metric.thinLine) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .shadow(color: theme.composerShadow,
                                radius: Theme.Metric.standard,
                                y: Theme.Metric.small)
                        .padding(Theme.Metric.large)
                        .transition(.scale(scale: 0.84).combined(with: .opacity))
                        .accessibilityLabel("回到底部")
                    }
                }
                .animation(.easeOut(duration: 0.18), value: isAtBottom)
                .onChange(of: model.bottomRequest) { _ in scrollToBottom(proxy) }
                .onChange(of: model.liveText) { _ in scrollToBottom(proxy) }
                .onChange(of: model.liveThinking) { _ in scrollToBottom(proxy) }
                .onChange(of: model.highlightedID) { id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
                .task {
                    model.start()
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    scrollToBottom(proxy, animated: false)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: Theme.Metric.zero) {
                ChatTopBar(
                    model: model,
                    openHistory: { showHistory = true },
                    openControls: { showControls = true },
                    openAppearance: { showAppearance = true }
                )
            }
            .safeAreaInset(edge: .bottom, spacing: Theme.Metric.zero) {
                VStack(spacing: Theme.Metric.small) {
                    if !model.error.isEmpty {
                        Text(model.error).font(theme.font(.metadata)).foregroundStyle(theme.warning).lineLimit(2)
                    }
                    Composer(model: model) { showControls = true }
                }
                .padding(.horizontal, Theme.Metric.composerHorizontal)
                .padding(.bottom, Theme.Metric.composerBottom)
            }
            .sheet(isPresented: $showHistory) { HistoryFinder(model: model) }
            .sheet(isPresented: $showControls) { ChatControls(model: model) }
            .sheet(isPresented: $showAppearance) { AppearanceSettings() }
        }
        .onDisappear { model.stop() }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let action = { proxy.scrollTo("chat-bottom", anchor: .bottom) }
        if animated { withAnimation(.easeOut(duration: 0.18), action) } else { action() }
    }
}

private struct ChatDateDivider: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: Theme
    let date: Date

    var body: some View {
        Text(date, format: .dateTime.month().day().weekday(.wide))
            .font(theme.font(.metadata))
            .foregroundStyle(theme.timestampText)
            .padding(.horizontal, Theme.Metric.roomy)
            .padding(.vertical, Theme.Metric.small)
            .background(theme.panelFill(), in: Capsule())
            .overlay { Capsule().stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.hairline) }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Metric.small)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct MessageRow: View {
    @EnvironmentObject private var theme: Theme
    let message: ChatMessage
    @ObservedObject var model: ChatViewModel

    var body: some View {
        VStack(alignment: message.isMine ? .trailing : .leading, spacing: Theme.Metric.compact) {
            if message.kind == "alarm" {
                AlarmBlock(text: "闹钟响了", detail: message.alarmNote ?? "")
            }

            if let thought = message.think, !thought.isEmpty {
                ThinkBlock(text: thought, cut: message.thinkCut)
            }

            messageBody

            HStack(spacing: Theme.Metric.compact) {
                if message.kind == "push" { Label("推送到了你手机", systemImage: "megaphone") }
                Text(message.date, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                Button { UIPasteboard.general.string = message.body } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("复制")
                if message.isMine {
                    Button { model.resend(message) } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("重发")
                }
                if let cache = message.cache, !message.isMine { Text("⚡\(cache)%") }
                if let hr = message.hr, !message.isMine { Text("♥\(hr)") }
            }
            .font(theme.font(.metadata))
            .foregroundStyle(theme.timestampText)
            .padding(.horizontal, Theme.Metric.metadataInset)
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
        .contextMenu {
            if !message.body.isEmpty {
                Button { UIPasteboard.general.string = message.body } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
            }
            if message.isMine {
                Button { model.resend(message) } label: {
                    Label("放回输入框", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    @ViewBuilder private var messageBody: some View {
        if message.kind == "alarm-auto" {
            AlarmBlock(text: "定闹钟 · 守夜", detail: message.body)
        } else if message.kind == "alarm-skip" {
            AlarmBlock(text: "闹钟到点 · \(message.why ?? "正聊着")，跳过了", detail: alarmSkipDetail)
        } else if message.kind == "call" {
            CallCard(message: message)
        } else if let segments = message.seg, !message.isMine, !segments.isEmpty {
            if let images = message.img, !images.isEmpty {
                Bubble(text: "", mine: false, images: images)
            }
            ForEach(Array(displaySegments(segments).enumerated()), id: \.offset) { _, segment in
                if segment.k == "t" {
                    Bubble(text: segment.s, mine: false, images: [], presentation: model.presentation(for: segment.s))
                } else {
                    StepRow(text: segment.s)
                }
            }
        } else {
            Bubble(text: message.body,
                   mine: message.isMine,
                   images: message.img ?? [],
                   voice: message.voice,
                   album: message.album,
                   presentation: model.presentation(for: message.body))
            if !message.isMine, let tools = message.tools, !tools.isEmpty {
                StepRows(items: message.toolNotes ?? tools)
            }
        }
    }

    private var alarmSkipDetail: String {
        var pieces = [message.body]
        if let due = message.due { pieces.append("原定 \(clock(due))") }
        if let next = message.next { pieces.append("下一只 \(clock(next))") }
        return pieces.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func displaySegments(_ segments: [ChatSegment]) -> [ChatSegment] {
        var alarmNotes = (message.toolNotes ?? []).filter(ToolPresentation.isAlarm)
        return segments.map { segment in
            guard segment.k != "t", ToolPresentation.isAlarm(segment.s), !alarmNotes.isEmpty else { return segment }
            return ChatSegment(k: segment.k, s: alarmNotes.removeFirst())
        }
    }

    private func clock(_ milliseconds: Double) -> String {
        Date(timeIntervalSince1970: milliseconds / 1_000).formatted(.dateTime.hour().minute())
    }
}

private struct LiveMessageRow: View {
    @EnvironmentObject private var theme: Theme
    @ObservedObject var model: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metric.compact) {
            if !model.liveThinking.isEmpty {
                ThinkBlock(text: model.liveThinking)
            }
            if !model.liveTools.isEmpty {
                StepRows(items: model.liveTools.uniqued())
            }
            if !model.liveText.isEmpty {
                Bubble(text: model.liveText, mine: false, images: [], streaming: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Bubble: View {
    @EnvironmentObject private var theme: Theme
    let text: String
    let mine: Bool
    let images: [String]
    var voice: VoiceMeta?
    var album: AlbumMeta?
    var streaming = false
    var presentation: RichTextPresentation?

    var body: some View {
        GlassBubble(mine: mine) {
            VStack(alignment: .leading, spacing: Theme.Metric.standard) {
                if album != nil || !images.isEmpty { AlbumRef(images: images, album: album) }
                if let voice, let file = voice.file, !file.isEmpty, let url = ChatAPI.mediaURL(file) {
                    VoiceBar(url: url, seconds: voice.secs, mine: mine)
                }
                if let voice {
                    Label(["语音", voice.secs.map { "\($0)秒" }, voice.mood].compactMap { $0 }.joined(separator: " · "),
                          systemImage: "mic")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.metaText)
                }
                if let presentation {
                    RichMessageText(presentation: presentation)
                } else if !text.isEmpty {
                    Text(text)
                        .lineSpacing(theme.bubbleLineSpacing)
                        .textSelection(.enabled)
                }
                if streaming {
                    RoundedRectangle(cornerRadius: Theme.Metric.thinLine)
                        .fill(theme.metaText)
                        .frame(width: Theme.Metric.tiny, height: Theme.Metric.section)
                }
            }
            .font(theme.font(.bubble))
            .foregroundStyle(theme.bubbleText)
        }
    }
}

private struct RichMessageText: View {
    @EnvironmentObject private var theme: Theme
    let presentation: RichTextPresentation
    @State private var showHTML = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metric.standard) {
            if !presentation.attributed.characters.isEmpty {
                Text(presentation.attributed)
                    .font(theme.font(.bubble))
                    .lineSpacing(theme.bubbleLineSpacing)
                    .textSelection(.enabled)
            }
            if let music = presentation.music {
                MusicCard(music: music)
            }
            if presentation.artifact != nil {
                Button { showHTML = true } label: {
                    Label("他做了一张网页卡片", systemImage: "sparkles.rectangle.stack")
                        .font(theme.font(.cardBody)).fontWeight(.medium)
                        .padding(Theme.Metric.roomy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.embeddedCardFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.toolRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showHTML) {
            if let artifact = presentation.artifact {
                NavigationStack {
                    HTMLWebView(html: artifact.html)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("他做的卡片")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) { Button("关上") { showHTML = false } }
                        }
                }
            }
        }
    }
}

private struct HTMLWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.loadHTMLString(html, baseURL: nil)
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

private struct CallCard: View {
    @EnvironmentObject private var theme: Theme
    let message: ChatMessage
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: Theme.Metric.standard) {
                ForEach(Array((message.call?.turns ?? []).enumerated()), id: \.offset) { _, turn in
                    Text("**\(turn.role == "user" ? "你" : "他")**  \(turn.text)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if message.call?.turns?.isEmpty != false {
                    Text("（没有逐字记录）").foregroundStyle(theme.metaText)
                }
            }
            .font(theme.font(.cardBody)).padding(.top, Theme.Metric.standard)
        } label: {
            Label([message.body, message.call?.reason].compactMap { $0 }.joined(separator: " · "),
                  systemImage: "phone.fill")
                .fontWeight(.medium)
        }
        .foregroundStyle(theme.bubbleText)
        .padding(Theme.Metric.large)
        .background(theme.cardSolid.opacity(theme.glassAlpha),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius))
        .frame(maxWidth: Theme.Metric.bubbleMaxWidth)
    }
}

private struct ChatControls: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: Theme
    @ObservedObject var model: ChatViewModel
    @State private var selectedModel: String
    @State private var selectedEffort: String
    @State private var thinking: Bool
    @State private var saving = false

    private let models = [
        "claude-fable-5-1[1m]",
        "claude-fable-5-1",
        "claude-opus-4-6",
        "claude-opus-4-6[1m]",
        "claude-opus-5",
        "claude-sonnet-5"
    ]

    init(model: ChatViewModel) {
        self.model = model
        _selectedModel = State(initialValue: model.model)
        _selectedEffort = State(initialValue: model.effort)
        _thinking = State(initialValue: model.nativeThinking)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        ContextGauge(value: model.contextPercent)
                        VStack(alignment: .leading) {
                            Text("记忆水位 \(model.contextPercent)%")
                            Text(model.modelLabel).font(theme.font(.metadata)).foregroundStyle(theme.metaText)
                        }
                    }
                }
                Section("模型") {
                    Picker("模型", selection: $selectedModel) {
                        ForEach(models, id: \.self) { Text(modelName($0)).tag($0) }
                    }
                    Picker("思考强度", selection: $selectedEffort) {
                        Text("默认").tag("")
                        ForEach(["low", "medium", "high", "xhigh", "max"], id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("显示原生思考", isOn: $thinking)
                }
                Section {
                    Text("这些设置从下一条消息开始生效。")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.metaText)
                }
            }
            .navigationTitle("聊天设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中…" : "保存") { Task { await save() } }.disabled(saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        await model.updateModel(selectedModel)
        await model.updateEffort(selectedEffort)
        await model.updateNativeThinking(thinking)
        saving = false
        dismiss()
    }

    private func modelName(_ value: String) -> String {
        switch value {
        case "claude-fable-5-1[1m]": return "Fable 5.1 · 1M"
        case "claude-fable-5-1": return "Fable 5.1"
        case "claude-opus-4-6": return "Opus 4.6"
        case "claude-opus-4-6[1m]": return "Opus 4.6 · 1M"
        case "claude-opus-5": return "Opus 5"
        case "claude-sonnet-5": return "Sonnet 5"
        default: return value
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
