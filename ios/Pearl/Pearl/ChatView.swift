import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import WebKit

struct ChatView: View {
    @StateObject private var model = ChatViewModel()
    @State private var showHistory = false
    @State private var showControls = false
    @State private var showAppearance = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if model.hasMore {
                            Button("↑ 看更早的") { Task { await model.loadOlder() } }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }

                        ForEach(model.messages) { message in
                            MessageRow(message: message, model: model)
                                .id(message.id)
                                .padding(.vertical, 1)
                                .overlay {
                                    if model.highlightedID == message.id {
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                                            .padding(-4)
                                    }
                                }
                        }

                        if model.isStreaming || !model.liveText.isEmpty || !model.liveThinking.isEmpty {
                            LiveMessageRow(model: model).id("live-message")
                        }

                        if model.hasNewer {
                            Button("↓ 回到现在") { Task { await model.goLatest() } }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }

                        Color.clear.frame(height: 1).id("chat-bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(ChatBackground())
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
            .navigationTitle("慢慢说")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showControls = true } label: {
                        ContextGauge(value: model.contextPercent)
                    }
                    .accessibilityLabel("聊天设置，记忆水位 \(model.contextPercent)%")
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("慢慢说")
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Color.pearlInk)
                        Text(model.status.isEmpty ? "你说，我听着。" : model.status)
                            .font(.system(size: 10.5, design: .serif))
                            .foregroundStyle(Color.pearlSoft)
                            .lineLimit(1)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    Button { showAppearance = true } label: {
                        Circle()
                            .fill(Color.pearlField)
                            .frame(width: 29, height: 29)
                            .overlay(Image(systemName: "paintpalette").foregroundStyle(Color.pearlAccent))
                    }
                    .accessibilityLabel("外观设置")
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 4) {
                    if !model.error.isEmpty {
                        Text(model.error).font(.caption).foregroundStyle(.red).lineLimit(2)
                    }
                    ComposerView(model: model)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 7)
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

private struct ContextGauge: View {
    let value: Int

    var body: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(value) / 100)
                .stroke(value > 82 ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)").font(.system(size: 8, weight: .bold, design: .rounded))
        }
        .frame(width: 27, height: 27)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    @ObservedObject var model: ChatViewModel

    var body: some View {
        VStack(alignment: message.isMine ? .trailing : .leading, spacing: 6) {
            if message.kind == "alarm" {
                Label(message.alarmNote.map { "闹钟响了 · \($0)" } ?? "闹钟响了", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let thought = message.think, !thought.isEmpty {
                ThinkBlock(text: thought, cut: message.thinkCut)
            }

            messageBody

            HStack(spacing: 6) {
                if message.kind == "push" { Label("推送到了你手机", systemImage: "megaphone") }
                Text(message.date, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                if let cache = message.cache, !message.isMine { Text("⚡\(cache)%") }
            }
            .font(.system(size: 9, design: .serif))
            .foregroundStyle(Color.pearlSoft.opacity(0.65))
            .padding(.horizontal, 5)
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
            ToolBlock(text: message.body, overrideLabel: "定闹钟 · 守夜")
        } else if message.kind == "alarm-skip" {
            ToolBlock(text: alarmSkipDetail, overrideLabel: "闹钟到点 · \(message.why ?? "正聊着")，跳过了")
        } else if message.kind == "call" {
            CallCard(message: message)
        } else if let segments = message.seg, !message.isMine, !segments.isEmpty {
            if let images = message.img, !images.isEmpty {
                Bubble(text: "", mine: false, images: images)
            }
            ForEach(Array(displaySegments(segments).enumerated()), id: \.offset) { _, segment in
                if segment.k == "t" {
                    Bubble(text: segment.s, mine: false, images: [])
                } else {
                    ToolBlock(text: segment.s)
                }
            }
        } else {
            Bubble(text: message.body,
                   mine: message.isMine,
                   images: message.img ?? [],
                   voice: message.voice,
                   album: message.album)
            if !message.isMine, let tools = message.tools, !tools.isEmpty {
                ToolBlock(text: (message.toolNotes?.joined(separator: "\n") ?? tools.joined(separator: " · ")),
                          overrideLabel: (message.toolNotes ?? tools).map(ToolPresentation.shortName).uniqued().joined(separator: " · "))
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
    @ObservedObject var model: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.liveThinking.isEmpty {
                ThinkBlock(text: model.liveThinking, startsOpen: true)
            }
            if !model.liveTools.isEmpty {
                ToolBlock(text: model.liveTools.uniqued().joined(separator: " · "), overrideLabel: "正在动手")
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

    var body: some View {
        GlassBubble(mine: mine) {
            VStack(alignment: .leading, spacing: Theme.Metric.standard) {
                if let album {
                    Label("相册\(album.title.map { "《\($0)》" } ?? "")", systemImage: "photo.on.rectangle")
                        .font(theme.font(.metadata))
                }
                if let voice, let file = voice.file, !file.isEmpty, let url = ChatAPI.mediaURL(file) {
                    AudioBubble(url: url, seconds: voice.secs)
                }
                ForEach(images, id: \.self) { name in
                    AsyncImage(url: ChatAPI.mediaURL(name)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            Label("图片没加载出来", systemImage: "photo.badge.exclamationmark")
                                .frame(maxWidth: .infinity, minHeight: Theme.Metric.imageErrorHeight)
                        } else {
                            RoundedRectangle(cornerRadius: Theme.Metric.imageRadius)
                                .fill(theme.cardSolid)
                                .frame(height: Theme.Metric.imagePlaceholderHeight)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.imageRadius, style: .continuous))
                }
                if let voice {
                    Label(["语音", voice.secs.map { "\($0)秒" }, voice.mood].compactMap { $0 }.joined(separator: " · "),
                          systemImage: "mic")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.metaText)
                }
                if !text.isEmpty { RichMessageText(text: text) }
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
    let text: String
    @State private var showHTML = false

    private var artifact: HTMLArtifact? { HTMLArtifact.parse(text) }
    private var music: MusicInfo? { MusicInfo.parse(text) }
    private var plain: String {
        var result = artifact.map { text.replacingOccurrences(of: $0.source, with: "") } ?? text
        if let music { result = result.replacingOccurrences(of: music.source, with: "") }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !plain.isEmpty {
                Text((try? AttributedString(markdown: plain,
                                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                     ?? AttributedString(plain))
                    .font(.system(size: 14, design: .serif))
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            if let music {
                Link(destination: music.url) {
                    HStack(spacing: 10) {
                        AsyncImage(url: music.cover) { image in image.resizable().scaledToFill() } placeholder: { Color.white.opacity(0.15) }
                            .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(music.name).fontWeight(.semibold).lineLimit(1)
                            Text(music.artist).font(.caption).opacity(0.75).lineLimit(1)
                            if !music.note.isEmpty { Text(music.note).font(.caption2).lineLimit(1) }
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                    }
                    .padding(8)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
            if artifact != nil {
                Button { showHTML = true } label: {
                    Label("他做了一张网页卡片", systemImage: "sparkles.rectangle.stack")
                        .font(.subheadline).fontWeight(.medium)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showHTML) {
            if let artifact {
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

private struct HTMLArtifact {
    let source: String
    let html: String

    static func parse(_ text: String) -> HTMLArtifact? {
        guard let regex = try? NSRegularExpression(pattern: "```html\\s*\\n([\\s\\S]*?)```"),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let sourceRange = Range(match.range(at: 0), in: text),
              let bodyRange = Range(match.range(at: 1), in: text) else { return nil }
        return HTMLArtifact(source: String(text[sourceRange]), html: String(text[bodyRange]))
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

private struct MusicInfo {
    let source: String
    let name: String
    let artist: String
    let cover: URL?
    let note: String
    let url: URL

    static func parse(_ text: String) -> MusicInfo? {
        let pattern = #"\[music:(\d+):([^\[\]:]+?):([^\[\]:]*?):(https?:[^\]|]*)\|?([^\]]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let full = Range(match.range(at: 0), in: text) else { return nil }
        func group(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }
        var parts = URLComponents(url: URL(string: "/pages/music.html", relativeTo: ChatAPI.baseURL)!.absoluteURL,
                                  resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            URLQueryItem(name: "id", value: group(1)),
            URLQueryItem(name: "name", value: group(2)),
            URLQueryItem(name: "artist", value: group(3)),
            URLQueryItem(name: "pic", value: group(4))
        ]
        return MusicInfo(source: String(text[full]), name: group(2), artist: group(3),
                         cover: URL(string: group(4)), note: group(5), url: parts.url!)
    }
}

private struct CallCard: View {
    let message: ChatMessage
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array((message.call?.turns ?? []).enumerated()), id: \.offset) { _, turn in
                    Text("**\(turn.role == "user" ? "你" : "他")**  \(turn.text)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if message.call?.turns?.isEmpty != false { Text("（没有逐字记录）").foregroundStyle(.secondary) }
            }
            .font(.subheadline).padding(.top, 8)
        } label: {
            Label([message.body, message.call?.reason].compactMap { $0 }.joined(separator: " · "),
                  systemImage: "phone.fill")
                .fontWeight(.medium)
        }
        .padding(13)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: 320)
    }
}

private struct ToolBlock: View {
    let text: String
    var overrideLabel: String?
    @State private var expanded = false
    @State private var showCard = false

    private var presentation: ToolPresentation { ToolPresentation.parse(text, label: overrideLabel) }

    var body: some View {
        Group {
            if let audio = presentation.audio {
                VStack(alignment: .leading, spacing: 7) {
                    AudioBubble(url: audio, seconds: nil)
                    if !presentation.detail.isEmpty {
                        Text(presentation.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(11)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 320, alignment: .leading)
            } else if presentation.card {
                Button { showCard = true } label: { cardFace }
                    .buttonStyle(.plain)
            } else if let url = presentation.url {
                Link(destination: url) { cardFace }.buttonStyle(.plain)
            } else {
                DisclosureGroup(isExpanded: $expanded) {
                    if !presentation.detail.isEmpty {
                        Text(presentation.detail).font(.caption).foregroundStyle(.secondary)
                            .textSelection(.enabled).padding(.top, 5)
                    }
                } label: {
                    Label(presentation.label, systemImage: "hammer")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
                .frame(maxWidth: 320, alignment: .leading)
            }
        }
        .sheet(isPresented: $showCard) {
            WrittenCard(label: presentation.label, content: presentation.detail)
        }
    }

    private var cardFace: some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.audio != nil ? "waveform" : presentation.url != nil ? "arrow.up.right.square" : "heart.text.square")
                .frame(width: 28, height: 28).background(.thinMaterial, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.label).font(.subheadline).fontWeight(.semibold)
                Text(presentation.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 320)
    }
}

private struct ToolPresentation {
    let label: String
    let detail: String
    let card: Bool
    let audio: URL?
    let url: URL?

    static func parse(_ raw: String, label forced: String? = nil) -> ToolPresentation {
        let text = raw.replacingOccurrences(of: "[记号] ", with: "")
        if let j = json(in: text, marker: "voice_note"), let file = j["file"] as? String {
            return ToolPresentation(label: "语音", detail: j["text"] as? String ?? "点开播放",
                                    card: false, audio: ChatAPI.mediaURL(file), url: ChatAPI.mediaURL(file))
        }
        if let j = json(in: text, marker: "tarot_draw") {
            let id = j["id"] as? String ?? ""
            let q = j["q"] as? String ?? "今天的牌"
            return ToolPresentation(label: "问牌 · \(q)", detail: "点开看牌面", card: false,
                                    audio: nil, url: pageURL("/pages/tarot.html", id: id))
        }
        if let j = json(in: text, marker: "tarot_reading") {
            return ToolPresentation(label: "写下答案", detail: j["text"] as? String ?? "", card: true,
                                    audio: nil, url: nil)
        }
        if let j = json(in: text, marker: "mail_draft") {
            let id = j["id"] as? String ?? ""
            let to = string(j["to"])
            let subject = j["subject"] as? String ?? ""
            let body = j["body"] as? String ?? ""
            return ToolPresentation(label: "回信草稿", detail: "给 \(to) · \(subject)\n\(body)", card: id.isEmpty,
                                    audio: nil, url: id.isEmpty ? nil : pageURL("/pages/mail-review.html", id: id))
        }
        if let j = json(in: text, marker: "mcp__ob__murmur") {
            return ToolPresentation(label: "爸爸的碎碎念", detail: j["content"] as? String ?? "", card: true,
                                    audio: nil, url: nil)
        }
        if let j = json(in: text, marker: "mcp__ob__hold") {
            let tags = string(j["tags"])
            let label = tags.contains("性爱日记") ? "爸爸的性爱日记" : tags.contains("日记") ? "爸爸的日记" : "爸爸记下的"
            return ToolPresentation(label: label, detail: j["content"] as? String ?? "", card: true,
                                    audio: nil, url: nil)
        }
        if let j = json(in: text, marker: "note_write") {
            return ToolPresentation(label: "爸爸的便签", detail: j["text"] as? String ?? "", card: true,
                                    audio: nil, url: nil)
        }
        if let j = json(in: text, marker: "card_write") {
            let kind = j["type"] as? String ?? "卡片"
            let title = j["title"] as? String ?? ""
            let body = j["body"] as? String ?? ""
            return ToolPresentation(label: kind == "记忆" ? "爸爸记下的" : kind,
                                    detail: [title, body].filter { !$0.isEmpty }.joined(separator: "\n\n"),
                                    card: true, audio: nil, url: nil)
        }
        let label = forced ?? shortName(text)
        return ToolPresentation(label: label, detail: text == label ? "" : text, card: false, audio: nil, url: nil)
    }

    static func shortName(_ raw: String) -> String {
        if isAlarm(raw) { return "Alarm" }
        if raw.contains("ScheduleWakeup") { return "定闹钟" }
        if raw.contains("play_music") || raw.contains("music_card") { return "放歌" }
        if raw.contains("WebSearch") || raw.contains("WebFetch") { return "上网" }
        if raw.contains("mcp__ob__") { return raw.contains("hold") || raw.contains("murmur") ? "写入记忆" : "读取记忆" }
        if raw.contains("mcp__mail__") || raw.contains("mail_draft") { return "邮箱" }
        if raw.contains("mcp__read__") { return "共读" }
        if raw.contains("mcp__engawa") { return "檐廊" }
        if raw.contains("mcp__atrio") { return "小客厅" }
        if raw.contains("Read(") { return "读取文件" }
        if raw.contains("Write(") || raw.contains("Edit(") { return "写入文件" }
        if raw.contains("Bash(") { return "执行命令" }
        return raw.split(separator: "(").first.map(String.init) ?? "动手做事"
    }

    static func isAlarm(_ raw: String) -> Bool {
        raw.contains("chat-alarm.js") || raw.range(of: #"^(定|续|停了|看了眼)闹钟"#, options: .regularExpression) != nil
    }

    private static func json(in text: String, marker: String) -> [String: Any]? {
        guard let markerRange = text.range(of: marker),
              let open = text[markerRange.upperBound...].firstIndex(of: "{"),
              let close = text.lastIndex(of: "}"), open <= close,
              let data = String(text[open...close]).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func string(_ value: Any?) -> String {
        if let strings = value as? [String] { return strings.joined(separator: ", ") }
        guard let value else { return "" }
        return String(describing: value)
    }

    private static func pageURL(_ path: String, id: String) -> URL? {
        guard !id.isEmpty else { return nil }
        var parts = URLComponents(url: URL(string: path, relativeTo: ChatAPI.baseURL)!.absoluteURL,
                                  resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "id", value: id)]
        return parts.url
    }
}

private struct WrittenCard: View {
    @Environment(\.dismiss) private var dismiss
    let label: String
    let content: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(label, systemImage: "heart").font(.caption).foregroundStyle(.secondary)
                    Text(content).font(.system(.body, design: .serif)).lineSpacing(8).textSelection(.enabled)
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ChatBackground())
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关上") { dismiss() } } }
        }
    }
}

private struct AudioBubble: View {
    @StateObject private var player: RemoteAudioPlayer
    let seconds: Int?

    init(url: URL, seconds: Int?) {
        _player = StateObject(wrappedValue: RemoteAudioPlayer(url: url))
        self.seconds = seconds
    }

    var body: some View {
        Button { player.toggle() } label: {
            HStack(spacing: 9) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                Image(systemName: "waveform").font(.title3)
                if let seconds, seconds > 0 { Text("\(seconds)″").font(.caption.monospacedDigit()) }
            }
            .frame(minWidth: 105, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class RemoteAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    private let player: AVPlayer
    private var token: NSObjectProtocol?

    init(url: URL) {
        player = AVPlayer(url: url)
        token = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                       object: player.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
    }

    deinit { if let token { NotificationCenter.default.removeObserver(token) } }

    func toggle() {
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }
}

private struct ComposerView: View {
    @ObservedObject var model: ChatViewModel
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @FocusState private var focused: Bool

    private var canSend: Bool {
        model.isStreaming || !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.pendingImages.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !model.pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.pendingImages) { item in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: item.image).resizable().scaledToFill()
                                    .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 10))
                                Button { model.removeImage(item.id) } label: {
                                    Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.7))
                                }
                                .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .padding(.top, 5)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                HStack(alignment: .bottom, spacing: 5) {
                    PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 3, matching: .images) {
                        Image(systemName: "paperclip").frame(width: 29, height: 34)
                    }
                    .disabled(model.pendingImages.count >= 3)

                    Button { model.toggleRecording() } label: {
                        Group {
                            if model.isSendingVoice { ProgressView() }
                            else { Image(systemName: model.isRecording ? "waveform.circle.fill" : "mic") }
                        }
                        .foregroundStyle(model.isRecording ? Color.red : Color.pearlAccent)
                        .frame(width: 29, height: 34)
                    }
                    .accessibilityLabel(model.isRecording ? "结束并发送录音" : "录音")

                    TextField(model.isRecording ? "正在录音…" : "把想说的放进来", text: $model.draft, axis: .vertical)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(Color.pearlInk)
                        .lineLimit(1...6).focused($focused).padding(.vertical, 8)
                        .disabled(model.isRecording)

                    if model.isRecording {
                        Button { model.cancelRecording() } label: {
                            Image(systemName: "xmark").frame(width: 34, height: 34)
                        }
                        .accessibilityLabel("取消录音")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.pearlField, in: Capsule())
                .overlay { Capsule().stroke(Color.pearlLine, lineWidth: 0.7) }
                .shadow(color: Color.black.opacity(0.09), radius: 18, y: 8)

                if !model.isRecording {
                    Button { Task { await model.sendOrStop() } } label: {
                        Image(systemName: model.isStreaming && model.draft.isEmpty && model.pendingImages.isEmpty ? "stop.fill" : "arrow.up")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 42, height: 42).background(Color.pearlAccent, in: Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain).disabled(!canSend).opacity(canSend ? 1 : 0.45)
                }
            }
        }
        .padding(.vertical, 7)
        .onChange(of: pickedPhotos) { items in
            Task {
                for item in items.prefix(max(0, 3 - model.pendingImages.count)) {
                    if let data = try? await item.loadTransferable(type: Data.self) { model.addImageData(data) }
                }
                pickedPhotos = []
            }
        }
    }
}

private struct HistoryFinder: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: ChatViewModel
    @State private var query = ""
    @State private var date = Date()
    @State private var hits: [SearchHit] = []
    @State private var busy = false
    @State private var error = ""
    private let api = ChatAPI()

    var body: some View {
        NavigationStack {
            List {
                Section("按日期") {
                    DatePicker("哪一天", selection: $date, in: ...Date(), displayedComponents: .date)
                    Button("跳到这一天") { Task { await jumpToDay() } }.disabled(busy)
                }
                if !hits.isEmpty {
                    Section("聊天记录") {
                        ForEach(hits) { hit in
                            Button {
                                Task { await model.jump(to: hit.id); dismiss() }
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(hit.role == "user" ? "你" : "他").font(.caption).foregroundStyle(.secondary)
                                    (Text(hit.before).foregroundColor(.secondary) + Text(hit.match).bold() + Text(hit.after).foregroundColor(.secondary))
                                        .font(.subheadline).lineLimit(3)
                                    Text(hit.date, format: .dateTime.year().month().day().hour().minute())
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }
            .overlay { if busy { ProgressView() } }
            .navigationTitle("翻旧话")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜聊天原文")
            .onSubmit(of: .search) { Task { await search() } }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关上") { dismiss() } } }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        busy = true
        defer { busy = false }
        do { hits = try await api.search(q).hits; error = "" }
        catch { self.error = error.localizedDescription }
    }

    private func jumpToDay() async {
        busy = true
        defer { busy = false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            let id = try await api.firstMessage(on: formatter.string(from: date))
            await model.jump(to: id, startOfDay: true)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ChatControls: View {
    @Environment(\.dismiss) private var dismiss
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
                            Text(model.modelLabel).font(.caption).foregroundStyle(.secondary)
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
                Section { Text("这些设置从下一条消息开始生效。").font(.caption).foregroundStyle(.secondary) }
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
