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
    let thinkCut: String?

    var isMine: Bool { role == "user" }
    var body: String { text ?? "" }
    var date: Date { Date(timeIntervalSince1970: at / 1_000) }
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
