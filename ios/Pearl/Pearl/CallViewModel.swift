import Combine
import Foundation
import SwiftUI

/// 一通电话的状态机(10.5):响铃 → 接通(他先开口) → 免手来回 → 软挂断余韵 → 结束。
/// 脑子在后端(聊天管道同一个他);这里只管听、放、顺序。
@MainActor
final class CallViewModel: ObservableObject {
    enum Phase { case loading, ringing, connecting, live, lingering, ended, failed }

    struct Line: Identifiable {
        let id = UUID()
        let mine: Bool
        var text: String
    }

    @Published var phase: Phase = .loading
    @Published var state = "来电…"
    @Published var reason = ""
    @Published var lines: [Line] = []
    @Published var elapsed = 0
    @Published var audio: CallAudio

    let callId: String
    private let api = CallAPI()
    private var turnGeneration = 0
    private var timer: Timer?
    private var lingerTask: Task<Void, Never>?
    private var startedAt: Date?
    private let lingerSeconds: UInt64 = 12
    private var audioSink: AnyCancellable?

    init(callId: String) {
        self.callId = callId
        audio = CallAudio()
        audioSink = audio.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }   // 耳朵的状态变了,页面跟着重画
        audio.onUtterance = { [weak self] wav in self?.herTurn(wav) }
        audio.onHearStart = { [weak self] in
            guard let self else { return }
            self.turnGeneration += 1          // 她开口=老轮作废
            self.lingerTask?.cancel(); self.lingerTask = nil
            if self.phase == .lingering { self.phase = .live }
            self.state = "在听你说…"
        }
    }

    func load() async {
        do {
            let record = try await api.call(id: callId)
            reason = record.reason ?? ""
            switch record.status {
            case "ringing": phase = .ringing; state = "来电…"
            case "answered": phase = .ringing; state = "接通中"
            default: phase = .ended; state = "这通已经结束了"
            }
        } catch {
            phase = .failed
            state = "这通电话找不到了"
        }
    }

    // MARK: 接听

    func answer() {
        guard phase == .ringing else { return }
        phase = .connecting
        state = "接通了，他开口中…"
        Task {
            do {
                try audio.activateSession()
                try audio.startMic()
            } catch {
                phase = .failed
                state = "拿不到麦克风，去设置里允许"
                return
            }
            try? await api.answer(id: callId)
            startTimer()
            await run(api.open(id: callId), isOpen: true)
        }
    }

    func reject(_ why: String) {
        Task { try? await api.reject(id: callId, reason: why) }
        phase = .ended
        state = "已回：\(why)"
    }

    func hangUp() {
        finish(message: "你挂了电话。")
    }

    private func finish(message: String) {
        guard phase != .ended else { return }
        phase = .ended
        state = message
        lingerTask?.cancel()
        timer?.invalidate()
        audio.stopAll()
        Task { try? await api.end(id: callId) }
    }

    // MARK: 一轮

    private func herTurn(_ wav: Data) {
        guard phase == .live || phase == .lingering || phase == .connecting else { return }   // 他开口那几秒她插嘴也算
        phase = .live
        state = "……"
        Task { await run(api.turn(id: callId, wav: wav), isOpen: false) }
    }

    private func run(_ stream: AsyncThrowingStream<CallEvent, Error>, isOpen: Bool) async {
        turnGeneration += 1
        let generation = turnGeneration
        var hangup = false
        var hisLine: Int?
        audio.listen()                       // 他开口时耳朵也开着,她随时能插嘴
        do {
            for try await event in stream {
                guard generation == turnGeneration else { continue }   // 老轮的话不放
                switch event {
                case .transcript(let text):
                    if text.isEmpty { state = "没听清，再说一遍" }
                    else { lines.append(Line(mine: true, text: text)); state = "他在想…" }
                case .segment(_, let text, let url):
                    if let index = hisLine { lines[index].text += " " + text }
                    else { lines.append(Line(mine: false, text: text)); hisLine = lines.count - 1 }
                    state = "他在说…（你出声他就停）"
                    audio.enqueue(url)
                case .done(let shouldHangup, _):
                    hangup = shouldHangup
                case .error(let message):
                    state = "出错：\(message)"
                }
            }
        } catch {
            guard generation == turnGeneration, phase != .ended else { return }
            state = "连不上：\(error.localizedDescription)"
            audio.listen()
            return
        }
        guard generation == turnGeneration, phase != .ended else { return }
        if isOpen { phase = .live }
        while !audio.isPlaybackIdle {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if generation != turnGeneration || phase == .ended { return }
        }
        if hangup { startLinger() } else { state = "在听你…"; audio.listen() }
    }

    private func startLinger() {
        phase = .lingering
        state = "他轻轻要挂了……还想说就出声"
        audio.listen()
        lingerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.lingerSeconds ?? 12) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.finish(message: "他挂了。晚安。")
        }
    }

    private func startTimer() {
        startedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = Int(Date().timeIntervalSince(startedAt))
            }
        }
    }
}
