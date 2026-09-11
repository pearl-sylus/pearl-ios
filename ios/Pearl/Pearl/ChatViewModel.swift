import AVFoundation
import Combine
import Foundation
import UIKit

struct PendingImage: Identifiable {
    let id = UUID()
    let data: Data
    let image: UIImage
}

@MainActor
final class ChatViewModel: NSObject, ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft = UserDefaults.standard.string(forKey: "chat-draft") ?? "" {
        didSet { UserDefaults.standard.set(draft, forKey: "chat-draft") }
    }
    @Published var pendingImages: [PendingImage] = []
    @Published var pendingVoice: VoiceMeta?
    @Published var hasMore = false
    @Published var hasNewer = false
    @Published var isStreaming = false
    @Published var isRecording = false
    @Published var isSendingVoice = false
    @Published var liveText = ""
    @Published var liveThinking = ""
    @Published var liveTools: [String] = []
    @Published var status = ""
    @Published var error = ""
    @Published var highlightedID: String?
    @Published var model = "claude-opus-4-6"
    @Published var effort = ""
    @Published var nativeThinking = true
    @Published var contextTokens = 0
    @Published var cacheHit: Int?
    @Published var bottomRequest = 0

    private let api = ChatAPI()
    private var streamTask: Task<Void, Never>?
    private var rawLiveText = ""
    private var nativeThinkingText = ""
    private var sendTicket: (signature: String, id: String)?
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?
    private var requestingMicrophone = false

    var contextPercent: Int {
        let cap = model.contains("[1m]") ? 1_000_000 : 200_000
        return min(100, Int((Double(contextTokens) / Double(cap) * 100).rounded()))
    }

    var modelLabel: String {
        let names = [
            "claude-fable-5-1[1m]": "Fable 5.1 1M",
            "claude-fable-5-1": "Fable 5.1",
            "claude-opus-4-6": "Opus 4.6",
            "claude-opus-4-6[1m]": "Opus 4.6 1M",
            "claude-opus-5": "Opus 5",
            "claude-sonnet-5": "Sonnet 5"
        ]
        return "\(names[model] ?? model) · \(effort.isEmpty ? "Default" : effort.capitalized)"
    }

    func start() {
        guard streamTask == nil else { return }
        streamTask = Task { [weak self] in
            guard let self else { return }
            async let history: Void = self.reload()
            async let controls: Void = self.loadControls()
            _ = await (history, controls)
            while !Task.isCancelled {
                do {
                    try await self.listenOnce()
                } catch is CancellationError {
                    return
                } catch {
                    self.status = "连接断了，正在重连…"
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
    }

    func reload() async {
        do {
            let page = try await api.load()
            messages = Self.unique(page.messages)
            hasMore = page.hasMore
            hasNewer = false
            bottomRequest += 1
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadOlder() async {
        guard hasMore, let first = messages.first else { return }
        do {
            let page = try await api.load(before: first.id)
            messages = Self.unique(page.messages + messages)
            hasMore = page.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func jump(to id: String, startOfDay: Bool = false) async {
        do {
            let page = try await api.context(anchor: id,
                                             before: startOfDay ? 0 : 35,
                                             after: startOfDay ? 60 : 35)
            messages = Self.unique(page.messages)
            hasMore = page.hasMoreBefore
            hasNewer = page.hasMoreAfter
            highlightedID = page.anchor
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    func goLatest() async {
        highlightedID = nil
        await reload()
    }

    func addImageData(_ data: Data) {
        guard pendingImages.count < 3,
              let image = UIImage(data: data),
              let jpeg = Self.compressedJPEG(image) else { return }
        pendingImages.append(PendingImage(data: jpeg, image: image))
    }

    func removeImage(_ id: UUID) {
        pendingImages.removeAll { $0.id == id }
    }

    func resend(_ message: ChatMessage) {
        draft = message.body
    }

    func sendOrStop() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if isStreaming && text.isEmpty && pendingImages.isEmpty && pendingVoice == nil {
            do { try await api.interrupt() } catch { self.error = error.localizedDescription }
            return
        }
        guard !text.isEmpty || !pendingImages.isEmpty || pendingVoice != nil else { return }
        if hasNewer { await goLatest() }

        let signature = text + "|" + pendingImages.map { $0.id.uuidString }.joined() + "|" + (pendingVoice?.file ?? "")
        let ticket: String
        if let pending = sendTicket, pending.signature == signature {
            ticket = pending.id
        } else {
            ticket = "ios-\(UUID().uuidString.lowercased())"
            sendTicket = (signature, ticket)
        }

        status = "送过去了，他在想"
        do {
            let response = try await api.send(text: text,
                                              clientID: ticket,
                                              images: pendingImages.map(\.data),
                                              voice: pendingVoice)
            sendTicket = nil
            draft = ""
            pendingImages = []
            pendingVoice = nil
            if !messages.contains(where: { $0.id == response.message.id }) {
                messages.append(response.message)
            }
            bottomRequest += 1
            isStreaming = response.streaming
            error = ""
        } catch {
            self.error = "这句没送到：\(error.localizedDescription)"
            status = ""
        }
    }

    func toggleRecording() {
        if isRecording {
            finishRecording(cancelled: false)
            return
        }
        guard !requestingMicrophone, !isSendingVoice else { return }
        requestingMicrophone = true
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            Task { @MainActor in
                guard let self else { return }
                self.requestingMicrophone = false
                if allowed { self.beginRecording() }
                else { self.error = "请在系统设置里允许“家”使用麦克风" }
            }
        }
    }

    func cancelRecording() {
        finishRecording(cancelled: true)
    }

    func updateModel(_ value: String) async {
        await updateSetting(key: "model", value: value)
        model = value
    }

    func updateEffort(_ value: String) async {
        await updateSetting(key: "effort", value: value)
        effort = value
    }

    func updateNativeThinking(_ value: Bool) async {
        await updateSetting(key: "nativeThinking", value: value)
        nativeThinking = value
    }

    private func loadControls() async {
        do {
            async let configRequest = api.pipeConfig()
            async let statusRequest = api.pipeStatus()
            let (config, pipe) = try await (configRequest, statusRequest)
            model = config.model ?? model
            effort = config.effort ?? ""
            nativeThinking = config.nativeThinking != false
            contextTokens = pipe.contextFresh == false ? 0 : (pipe.contextTokens ?? 0)
        } catch {
            // 聊天本身可用时，控制条失败不挡住页面。
        }
    }

    private func updateSetting(key: String, value: Any) async {
        do {
            try await api.setPipeValue(key: key, value: value)
            status = "记下了，下条消息生效"
            error = ""
        } catch {
            self.error = "没存上：\(error.localizedDescription)"
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("pearl-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else { throw URLError(.cannotCreateFile) }
            self.recorder = recorder
            recordingURL = url
            recordingStartedAt = Date()
            isRecording = true
            status = "正在录音，再点一下发送"
            error = ""
        } catch {
            self.error = "录音没开始：\(error.localizedDescription)"
        }
    }

    private func finishRecording(cancelled: Bool) {
        guard let recorder, let url = recordingURL else { return }
        let seconds = max(0, Int(Date().timeIntervalSince(recordingStartedAt ?? Date()).rounded()))
        recorder.stop()
        self.recorder = nil
        recordingURL = nil
        recordingStartedAt = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if cancelled {
            try? FileManager.default.removeItem(at: url)
            status = "取消了"
            return
        }
        guard seconds >= 1, let data = try? Data(contentsOf: url), !data.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            error = "太短了，多说一会儿"
            status = ""
            return
        }
        try? FileManager.default.removeItem(at: url)
        Task { await uploadRecording(data, seconds: seconds) }
    }

    private func uploadRecording(_ data: Data, seconds: Int) async {
        isSendingVoice = true
        status = "他在听…"
        do {
            let result = try await api.uploadVoice(data)
            if let fatal = result.error { throw ServerError(error: fatal) }
            pendingVoice = VoiceMeta(mood: result.mood?.mood,
                                     why: result.mood?.why,
                                     sound: result.sound,
                                     secs: seconds,
                                     file: result.file)
            draft = result.text ?? ""
            isSendingVoice = false
            await sendOrStop()
        } catch {
            isSendingVoice = false
            status = ""
            self.error = "语音没送出去：\(error.localizedDescription)"
        }
    }

    private func listenOnce() async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: api.streamRequest())
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        status = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: "), let data = String(line.dropFirst(6)).data(using: .utf8),
                  let event = try? JSONDecoder().decode(ChatEvent.self, from: data) else { continue }
            receive(event)
        }
    }

    private func receive(_ event: ChatEvent) {
        switch event.kind {
        case "catchup":
            guard event.src != "alarm" else { status = "他自己醒着，在忙…"; return }
            nativeThinkingText = event.thinking ?? ""
            rawLiveText = event.text ?? ""
            rebuildLiveText()
            isStreaming = !nativeThinkingText.isEmpty || !rawLiveText.isEmpty
        case "thinking":
            nativeThinkingText += event.text ?? ""
            rebuildLiveText()
            isStreaming = true
            status = "他在想"
        case "text":
            rawLiveText += event.text ?? ""
            rebuildLiveText()
            isStreaming = true
            status = ""
        case "tool":
            if let name = event.name { liveTools.append(toolLabel(name)) }
            isStreaming = true
        case "tool-live":
            status = event.name.map(toolLabel) ?? "他在动手"
        case "turn-end":
            if let tokens = event.contextTokens { contextTokens = tokens }
            if let usage = event.usage {
                let total = (usage.inputTokens ?? 0) + (usage.cacheReadInputTokens ?? 0) + (usage.cacheCreationInputTokens ?? 0)
                cacheHit = total > 0 ? Int((Double(usage.cacheReadInputTokens ?? 0) / Double(total) * 100).rounded()) : nil
            }
            Task {
                if !hasNewer { await reload() }
                clearLive()
            }
        case "flow":
            if !hasNewer { Task { await reload() } }
        case "proc" where event.state == "closed":
            clearLive()
        case "proc" where event.state == "spawned":
            status = "他刚醒，接上记忆要一小会"
        case "sys":
            if event.what == "api_retry" { status = "信号不太好，稍等" }
            if event.what == "alarm-fire" { status = "他自己醒了" }
            if event.what == "compressed" { Task { await loadControls() } }
            if event.what == "alarm-skip" || event.what == "alarm-auto" {
                if !hasNewer { Task { await reload() } }
            }
        case "error":
            error = event.message ?? "出了点问题"
        default:
            break
        }
    }

    private func rebuildLiveText() {
        let parsed = Self.splitMarkedThought(rawLiveText)
        liveText = parsed.body
        liveThinking = [nativeThinkingText, parsed.thought]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    private func clearLive() {
        rawLiveText = ""
        nativeThinkingText = ""
        liveText = ""
        liveThinking = ""
        liveTools = []
        isStreaming = false
        status = ""
    }

    private static func splitMarkedThought(_ raw: String) -> (thought: String, body: String) {
        let leading = raw.drop { $0.isWhitespace }
        guard leading.hasPrefix("[[心]]") else { return ("", raw) }
        let content = String(leading.dropFirst("[[心]]".count))
        guard let close = content.range(of: "[[/心]]") else { return (content, "") }
        return (String(content[..<close.lowerBound]),
                String(content[close.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func toolLabel(_ name: String) -> String {
        if name == "ScheduleWakeup" { return "定闹钟" }
        if name.hasPrefix("mcp__ob__") { return name.contains("hold") || name.contains("murmur") ? "写入记忆" : "读取记忆" }
        if name.hasPrefix("mcp__mail__") { return "邮箱" }
        if name.hasPrefix("mcp__read__") { return "共读" }
        if name.hasPrefix("mcp__engawa__") { return "檐廊" }
        if name.hasPrefix("mcp__atrio") { return "小客厅" }
        switch name {
        case "WebSearch", "WebFetch": return "上网"
        case "Read": return "读取文件"
        case "Write", "Edit": return "写入文件"
        case "Bash": return "执行命令"
        default: return "动手做事"
        }
    }

    private static func unique(_ input: [ChatMessage]) -> [ChatMessage] {
        var seen = Set<String>()
        return input.filter { seen.insert($0.id).inserted }
    }

    private static func compressedJPEG(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1_280 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
