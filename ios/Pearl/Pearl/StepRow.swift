import Foundation
import SwiftUI

struct StepRows: View {
    let items: [String]

    var body: some View {
        ForEach(ToolPresentation.groups(items)) { group in
            StepRow(items: group.items, overrideLabel: group.label)
        }
    }
}

struct StepRow: View {
    @EnvironmentObject private var theme: Theme
    let items: [String]
    var overrideLabel: String?
    @State private var expanded = false
    @State private var showCard = false

    init(text: String, overrideLabel: String? = nil) {
        items = [text]
        self.overrideLabel = overrideLabel
    }

    init(items: [String], overrideLabel: String? = nil) {
        self.items = items
        self.overrideLabel = overrideLabel
    }

    private var presentation: ToolPresentation {
        ToolPresentation.parse(items.first ?? "", label: overrideLabel)
    }

    var body: some View {
        Group {
            if items.count == 1, presentation.kind == .tarot {
                TarotCard(presentation: presentation)
            } else if items.count == 1, presentation.kind == .write {
                WriteCard(presentation: presentation)
            } else if items.count == 1, let audio = presentation.audio {
                VStack(alignment: .leading, spacing: Theme.Metric.compact) {
                    VoiceBar(url: audio, seconds: nil, mine: false)
                    if !presentation.detail.isEmpty {
                        Text(presentation.detail)
                            .font(theme.font(.toolDetail))
                            .foregroundStyle(theme.metaText)
                    }
                }
                .padding(Theme.Metric.roomy)
                .background(theme.thinkingFill(), in: shape)
            } else if items.count == 1, presentation.card {
                Button { showCard = true } label: { cardFace }.buttonStyle(.plain)
            } else if items.count == 1, let url = presentation.url {
                Link(destination: url) { cardFace }.buttonStyle(.plain)
            } else {
                disclosure
            }
        }
        .frame(maxWidth: Theme.Metric.stepMaxWidth, alignment: .leading)
        .sheet(isPresented: $showCard) {
            WriteCardDetail(label: presentation.label, content: presentation.detail)
        }
    }

    private var disclosure: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: Theme.Metric.compact) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .font(theme.font(.toolDetail))
                        .foregroundStyle(theme.thinkText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Metric.roomy)
                        .padding(.vertical, Theme.Metric.standard)
                        .background(theme.thinkingFill(), in: shape)
                }
            }
            .padding(.top, Theme.Metric.compact)
        } label: {
            Text(summary).font(theme.font(.thinkingLabel)).foregroundStyle(theme.metaText)
        }
        .tint(theme.metaText)
    }

    private var cardFace: some View {
        HStack(spacing: Theme.Metric.roomy) {
            Image(systemName: presentation.audio != nil ? "waveform" : presentation.url != nil ? "arrow.up.right.square" : "heart.text.square")
                .frame(width: Theme.Metric.cardIcon, height: Theme.Metric.cardIcon)
            VStack(alignment: .leading, spacing: Theme.Metric.tiny) {
                Text(presentation.label).font(theme.font(.cardTitle))
                Text(presentation.detail)
                    .font(theme.font(.cardBody))
                    .foregroundStyle(theme.metaText)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(theme.font(.metadata)).foregroundStyle(theme.thinkLabel)
        }
        .foregroundStyle(theme.bubbleText)
        .padding(Theme.Metric.roomy)
        .background(theme.thinkingFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
    }

    private var summary: String {
        let label = overrideLabel ?? presentation.label
        return items.count > 1 ? "\(label) ×\(items.count)  ⎿ Done" : "\(label)  ⎿ Done"
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metric.toolRadius, style: .continuous)
    }
}

struct ToolGroup: Identifiable {
    let label: String
    var items: [String]
    var id: String { label }
}

struct ToolPresentation {
    enum Kind: Equatable { case generic, voice, tarot, write }

    let label: String
    let detail: String
    let card: Bool
    let audio: URL?
    let url: URL?
    let kind: Kind

    init(label: String, detail: String, card: Bool, audio: URL?, url: URL?, kind: Kind = .generic) {
        self.label = label
        self.detail = detail
        self.card = card
        self.audio = audio
        self.url = url
        self.kind = kind
    }

    static func groups(_ items: [String]) -> [ToolGroup] {
        var result: [ToolGroup] = []
        for item in items {
            let label = shortName(item)
            if let index = result.firstIndex(where: { $0.label == label }) {
                result[index].items.append(item)
            } else {
                result.append(ToolGroup(label: label, items: [item]))
            }
        }
        return result
    }

    static func parse(_ raw: String, label forced: String? = nil) -> ToolPresentation {
        let text = raw.replacingOccurrences(of: "[记号] ", with: "")
        if let j = json(in: text, marker: "voice_note"), let file = j["file"] as? String {
            return ToolPresentation(label: "语音", detail: j["text"] as? String ?? "点开播放",
                                    card: false, audio: ChatAPI.mediaURL(file), url: ChatAPI.mediaURL(file), kind: .voice)
        }
        if let j = json(in: text, marker: "tarot_draw") {
            let id = j["id"] as? String ?? ""
            let q = j["q"] as? String ?? "今天的牌"
            return ToolPresentation(label: "问牌 · \(q)", detail: "点开看牌面", card: false,
                                    audio: nil, url: pageURL("/pages/tarot.html", id: id), kind: .tarot)
        }
        if let j = json(in: text, marker: "tarot_reading") {
            return ToolPresentation(label: "写下答案", detail: j["text"] as? String ?? "", card: true,
                                    audio: nil, url: nil, kind: .tarot)
        }
        if let j = json(in: text, marker: "mail_draft") {
            let id = j["id"] as? String ?? ""
            let to = string(j["to"])
            let subject = j["subject"] as? String ?? ""
            let body = j["body"] as? String ?? ""
            return ToolPresentation(label: "回信草稿", detail: "给 \(to) · \(subject)\n\(body)", card: id.isEmpty,
                                    audio: nil, url: id.isEmpty ? nil : pageURL("/pages/mail-review.html", id: id), kind: .write)
        }
        if let j = json(in: text, marker: "mcp__ob__murmur") {
            return ToolPresentation(label: "爸爸的碎碎念", detail: j["content"] as? String ?? "", card: true,
                                    audio: nil, url: nil, kind: .write)
        }
        if let j = json(in: text, marker: "mcp__ob__hold") {
            let tags = string(j["tags"])
            let label = tags.contains("性爱日记") ? "爸爸的性爱日记" : tags.contains("日记") ? "爸爸的日记" : "爸爸记下的"
            return ToolPresentation(label: label, detail: j["content"] as? String ?? "", card: true,
                                    audio: nil, url: nil, kind: .write)
        }
        if let j = json(in: text, marker: "note_write") {
            return ToolPresentation(label: "爸爸的便签", detail: j["text"] as? String ?? "", card: true,
                                    audio: nil, url: nil, kind: .write)
        }
        if let j = json(in: text, marker: "card_write") {
            let kind = j["type"] as? String ?? "卡片"
            let title = j["title"] as? String ?? ""
            let body = j["body"] as? String ?? ""
            return ToolPresentation(label: kind == "记忆" ? "爸爸记下的" : kind,
                                    detail: [title, body].filter { !$0.isEmpty }.joined(separator: "\n\n"),
                                    card: true, audio: nil, url: nil, kind: .write)
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

    static func json(in text: String, marker: String) -> [String: Any]? {
        guard let markerRange = text.range(of: marker),
              let open = text[markerRange.upperBound...].firstIndex(of: "{"),
              let close = text.lastIndex(of: "}"), open <= close,
              let data = String(text[open...close]).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func string(_ value: Any?) -> String {
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
