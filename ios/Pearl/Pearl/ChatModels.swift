import Foundation

struct ChatSegment: Decodable, Hashable {
    let k: String
    let s: String
}

struct VoiceMeta: Codable, Hashable {
    let mood: String?
    let why: String?
    let sound: String?
    let secs: Int?
    let file: String?
}

struct AlbumMeta: Decodable, Hashable {
    let id: String?
    let title: String?
}

struct CallTurn: Decodable, Hashable {
    let role: String
    let text: String
}

struct CallMeta: Decodable, Hashable {
    let reason: String?
    let turns: [CallTurn]?
}

struct ChatMessage: Decodable, Identifiable, Hashable {
    let id: String
    let at: Double
    let role: String
    let text: String?
    let img: [String]?
    let think: String?
    let kind: String?
    let call: CallMeta?
    let tools: [String]?
    let toolNotes: [String]?
    let seg: [ChatSegment]?
    let voice: VoiceMeta?
    let album: AlbumMeta?
    let alarmNote: String?
    let wokeAt: Double?
    let due: Double?
    let next: Double?
    let why: String?
    let cache: Int?
    let hr: Int?
    let thinkCut: String?

    var isMine: Bool { role == "user" }
    var body: String { text ?? "" }
    var date: Date { Date(timeIntervalSince1970: at / 1_000) }
}

struct RichTextPresentation {
    let attributed: AttributedString
    let artifact: HTMLArtifact?
    let music: MusicInfo?

    init(_ text: String) {
        artifact = HTMLArtifact.parse(text)
        music = MusicInfo.parse(text)
        var plain = artifact.map { text.replacingOccurrences(of: $0.source, with: "") } ?? text
        if let music { plain = plain.replacingOccurrences(of: music.source, with: "") }
        plain = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        attributed = (try? AttributedString(
            markdown: plain,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(plain)
    }
}

struct HTMLArtifact {
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

struct MusicInfo {
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
        guard var parts = URLComponents(
            url: URL(string: "/pages/music.html", relativeTo: ChatAPI.baseURL)!.absoluteURL,
            resolvingAgainstBaseURL: false
        ) else { return nil }
        parts.queryItems = [
            URLQueryItem(name: "id", value: group(1)),
            URLQueryItem(name: "name", value: group(2)),
            URLQueryItem(name: "artist", value: group(3)),
            URLQueryItem(name: "pic", value: group(4))
        ]
        guard let url = parts.url else { return nil }
        return MusicInfo(source: String(text[full]), name: group(2), artist: group(3),
                         cover: URL(string: group(4)), note: group(5), url: url)
    }
}

struct ChatPage: Decodable {
    let hasMore: Bool
    let messages: [ChatMessage]
}

struct ChatContextPage: Decodable {
    let anchor: String
    let hasMoreBefore: Bool
    let hasMoreAfter: Bool
    let messages: [ChatMessage]
}

struct SendResponse: Decodable {
    let streaming: Bool
    let message: ChatMessage
}

struct SearchHit: Decodable, Identifiable, Hashable {
    let id: String
    let at: Double
    let role: String
    let before: String
    let match: String
    let after: String

    var date: Date { Date(timeIntervalSince1970: at / 1_000) }
}

struct SearchPage: Decodable {
    let hits: [SearchHit]
    let hasMore: Bool
    let nextBefore: String?
}

struct ChatEvent: Decodable {
    let kind: String
    let text: String?
    let thinking: String?
    let name: String?
    let detail: String?
    let result: String?
    let what: String?
    let state: String?
    let message: String?
    let src: String?
    let contextTokens: Int?
    let usage: ChatUsage?
}

struct ChatUsage: Decodable {
    let inputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
    }
}

struct PipeConfig: Decodable {
    let model: String?
    let nativeThinking: Bool?
    let effort: String?
}

struct PipeStatus: Decodable {
    let contextTokens: Int?
    let contextFresh: Bool?
}

struct VoiceMood: Decodable {
    let mood: String?
    let why: String?
}

struct VoiceUploadResponse: Decodable {
    let text: String?
    let mood: VoiceMood?
    let sound: String?
    let file: String?
    let error: String?
    let errorListen: String?

    enum CodingKeys: String, CodingKey {
        case text, mood, sound, file, error
        case errorListen = "error_listen"
    }
}

struct ServerError: Decodable, LocalizedError {
    let error: String
    var errorDescription: String? { error }
}
