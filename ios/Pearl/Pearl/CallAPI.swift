import Foundation

/// 原生电话的网络层(10.5)。接口和暗房接听页一模一样,都打 dark.pearl-sylus.org 的 /api/voice/*
/// (暗房代注 cookie 转给 home 3010):读来电、接听、他先开口(open,SSE)、她说一句(turn,SSE)、挂断、拒接、应用内起呼。
struct CallRecord: Decodable {
    let id: String
    let reason: String?
    let status: String?
    let answered_at: String?
}

/// turn / open 两条 SSE 流上的事件
enum CallEvent {
    case transcript(String)
    case segment(index: Int, text: String, audio: URL)
    case done(hangup: Bool, reply: String)
    case error(String)
}

struct CallAPI {
    static let baseURL = ChatAPI.baseURL

    private func url(_ path: String) -> URL {
        URL(string: path, relativeTo: Self.baseURL)!.absoluteURL
    }

    private func post(_ path: String, json: [String: Any]? = nil) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func call(id: String) async throws -> CallRecord {
        var request = URLRequest(url: url("/api/voice/call/\(id)"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Wrap: Decodable { let call: CallRecord }
        return try JSONDecoder().decode(Wrap.self, from: data).call
    }

    /// 她打给他:应用内起一通(status 直接 answered,不推送)
    func start(reason: String) async throws -> String {
        let data = try await post("/api/voice/call/start", json: ["reason": reason])
        struct Wrap: Decodable { let id: String }
        return try JSONDecoder().decode(Wrap.self, from: data).id
    }

    func answer(id: String) async throws { _ = try await post("/api/voice/call/\(id)/answer") }
    func end(id: String) async throws { _ = try await post("/api/voice/call/\(id)/end") }
    func reject(id: String, reason: String) async throws {
        _ = try await post("/api/voice/call/\(id)/reject", json: ["reason": reason])
    }

    /// 接通第一句:他先开口。事件逐段回来(segment 带 mp3 地址)。
    func open(id: String) -> AsyncThrowingStream<CallEvent, Error> {
        var request = URLRequest(url: url("/api/voice/call/\(id)/open"))
        request.httpMethod = "POST"
        return stream(request)
    }

    /// 她说完一句:16k mono wav 进,他的话逐段出。
    func turn(id: String, wav: Data) -> AsyncThrowingStream<CallEvent, Error> {
        var request = URLRequest(url: url("/api/voice/call/\(id)/turn"))
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = wav
        return stream(request)
    }

    private func stream(_ request: URLRequest) -> AsyncThrowingStream<CallEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = request
                    request.timeoutInterval = 180
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    var event = ""
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            guard let data = payload.data(using: .utf8),
                                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                            switch event {
                            case "transcript":
                                continuation.yield(.transcript((obj["text"] as? String) ?? ""))
                            case "segment":
                                let rel = (obj["audio"] as? String) ?? ""
                                if let audio = URL(string: "/" + rel, relativeTo: Self.baseURL)?.absoluteURL {
                                    continuation.yield(.segment(index: (obj["idx"] as? Int) ?? 0,
                                                                text: (obj["text"] as? String) ?? "",
                                                                audio: audio))
                                }
                            case "done":
                                continuation.yield(.done(hangup: (obj["hangup"] as? Bool) ?? false,
                                                         reply: (obj["reply"] as? String) ?? ""))
                            case "error":
                                continuation.yield(.error((obj["message"] as? String) ?? "出错了"))
                            default:
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
