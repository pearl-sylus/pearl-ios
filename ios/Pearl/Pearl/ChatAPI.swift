import Foundation

struct ChatAPI {
    static let baseURL = URL(string: "https://dark.pearl-sylus.org")!

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var parts = URLComponents(url: URL(string: path, relativeTo: Self.baseURL)!.absoluteURL,
                                  resolvingAgainstBaseURL: false)!
        if !query.isEmpty { parts.queryItems = query }
        return parts.url!
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let problem = try? JSONDecoder().decode(ServerError.self, from: data) { throw problem }
            throw URLError(.badServerResponse)
        }
        return data
    }

    func load(before: String? = nil) async throws -> ChatPage {
        let query = before.map { [URLQueryItem(name: "before", value: $0)] } ?? []
        var request = URLRequest(url: url("/api/chat", query: query))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return try JSONDecoder().decode(ChatPage.self, from: await data(for: request))
    }

    func context(anchor: String, before: Int = 35, after: Int = 35) async throws -> ChatContextPage {
        let request = URLRequest(url: url("/api/chat/context", query: [
            URLQueryItem(name: "anchor", value: anchor),
            URLQueryItem(name: "before", value: String(before)),
            URLQueryItem(name: "after", value: String(after))
        ]))
        return try JSONDecoder().decode(ChatContextPage.self, from: await data(for: request))
    }

    func search(_ query: String, before: String? = nil) async throws -> SearchPage {
        var items = [URLQueryItem(name: "q", value: query)]
        if let before { items.append(URLQueryItem(name: "before", value: before)) }
        let request = URLRequest(url: url("/api/chat/search", query: items))
        return try JSONDecoder().decode(SearchPage.self, from: await data(for: request))
    }

    func firstMessage(on day: String) async throws -> String {
        let request = URLRequest(url: url("/api/chat/day", query: [URLQueryItem(name: "date", value: day)]))
        let object = try JSONSerialization.jsonObject(with: await data(for: request)) as? [String: Any]
        guard let id = object?["id"] as? String else { throw URLError(.cannotParseResponse) }
        return id
    }

    func send(text: String, clientID: String, images: [Data] = [], voice: VoiceMeta? = nil) async throws -> SendResponse {
        var body: [String: Any] = [
            "text": text,
            "clientId": clientID,
            "localTime": Self.localMinuteStamp()
        ]
        if !images.isEmpty {
            body["images"] = images.prefix(3).map { ["media_type": "image/jpeg", "data": $0.base64EncodedString()] }
        }
        if let voice {
            body["voice"] = [
                "mood": voice.mood ?? "",
                "why": voice.why ?? "",
                "sound": voice.sound ?? "",
                "secs": voice.secs ?? 0,
                "file": voice.file ?? ""
            ]
        }
        var request = URLRequest(url: url("/api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(SendResponse.self, from: await data(for: request))
    }

    func uploadVoice(_ recording: Data) async throws -> VoiceUploadResponse {
        var request = URLRequest(url: url("/api/voice-in"))
        request.httpMethod = "POST"
        request.timeoutInterval = 70
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = recording
        return try JSONDecoder().decode(VoiceUploadResponse.self, from: await data(for: request))
    }

    func interrupt() async throws {
        try await post("/api/chat/interrupt", body: [:])
    }

    func pipeConfig() async throws -> PipeConfig {
        try JSONDecoder().decode(PipeConfig.self, from: await data(for: URLRequest(url: url("/api/chat/pipe-config"))))
    }

    func pipeStatus() async throws -> PipeStatus {
        try JSONDecoder().decode(PipeStatus.self, from: await data(for: URLRequest(url: url("/api/chat/pipe-status"))))
    }

    func homeDashboard() async throws -> HomeDashboard {
        try JSONDecoder().decode(HomeDashboard.self, from: await data(for: URLRequest(url: url("/api/dash"))))
    }

    func days() async throws -> DaysResponse {
        try JSONDecoder().decode(DaysResponse.self, from: await data(for: URLRequest(url: url("/api/days"))))
    }

    func setPipeValue(key: String, value: Any) async throws {
        try await post("/api/chat/pipe-config", body: ["key": key, "value": value])
    }

    func streamRequest() -> URLRequest {
        var request = URLRequest(url: url("/api/chat/stream"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 60 * 60
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        return request
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await data(for: request)
    }

    static func mediaURL(_ name: String) -> URL? {
        URL(string: "/api/chat/media/\(name)", relativeTo: baseURL)?.absoluteURL
    }

    private static func localMinuteStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
