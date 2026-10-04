import AVFoundation
import Foundation

/// 原生电话的耳朵和嘴(10.5)。和暗房接听页同一套方子:
/// 麦克风常开 → 能量 VAD 自动切句(起话 0.020 / 静音 0.012 / 静 850ms 算一句) → 16k mono 16bit wav 交给后端;
/// 他的话一段一个 mp3,按顺序放;她一出声就掐掉正在放的(插嘴)。
@MainActor
final class CallAudio: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isHearing = false
    @Published private(set) var isSpeaking = false

    /// 她说完一句(已编成 wav)
    var onUtterance: (@MainActor (Data) -> Void)?
    /// 她刚开口(用来作废老轮、掐声音)
    var onHearStart: (@MainActor () -> Void)?

    private let engine = AVAudioEngine()
    private let pipe = ResamplePipe()   // 音频线程用,不在主 actor 上
    private var outFormat: AVAudioFormat { pipe.outFormat }

    // VAD 参数(和 call.js 一致)
    private let startRMS: Float = 0.020
    private let endRMS: Float = 0.012
    private let bargeMultiplier: Float = 1.4
    private let onsetFrames = 2
    private let endSilenceMs = 850.0
    private let minUtteranceMs = 350.0

    private var gate = true          // true = 不听(他在想的那几秒)
    private var voiced = 0
    private var inUtterance = false
    private var silentMs = 0.0
    private var utteranceMs = 0.0
    private var captured: [Float] = []
    private var preroll: [[Float]] = []
    // "我说完了"按钮的兜底缓冲(ios-app-where-it-breaks 02 第九堵墙):跟 VAD 完全无关,只要在收音就一直攒,按帧分块存,25 秒滚动
    private var rolling: [[Float]] = []
    private var rollingSamples = 0
    private let rollingMaxSamples = 16_000 * 25

    private var queue: [URL] = []
    private var player: AVAudioPlayer?
    private var playing = false
    private var playGeneration = 0
    private var delegateBox: PlayerDelegate?

    // MARK: 会话

    func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    func startMic() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        pipe.prepare(from: format)
        let pipe = self.pipe
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let mono = pipe.downsample(buffer) else { return }
            Task { @MainActor in self?.consume(mono) }
        }
        engine.prepare()
        try engine.start()
    }

    func stopMic() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        gate = true
        isListening = false
        isHearing = false
    }

    func listen() {
        resetVad()
        gate = false
        isListening = true
    }

    func hold() {
        gate = true
        isListening = false
    }

    // MARK: 采样 → 16k 单声道 见 ResamplePipe

    // MARK: VAD

    private func consume(_ frame: [Float]) {
        guard !frame.isEmpty else { return }
        rolling.append(frame); rollingSamples += frame.count
        while rollingSamples > rollingMaxSamples, let first = rolling.first { rollingSamples -= first.count; rolling.removeFirst() }
        guard !gate else { return }
        let frameMs = Double(frame.count) / outFormat.sampleRate * 1000
        var sum: Float = 0
        for sample in frame { sum += sample * sample }
        let rms = (sum / Float(frame.count)).squareRoot()
        let threshold = playing ? startRMS * bargeMultiplier : startRMS

        if !inUtterance {
            preroll.append(frame)
            if preroll.count > 3 { preroll.removeFirst() }
            if rms > threshold {
                voiced += 1
                if voiced >= onsetFrames {
                    if playing || !queue.isEmpty { bargeIn() }
                    inUtterance = true
                    captured = preroll.flatMap { $0 }
                    utteranceMs = Double(preroll.count) * frameMs
                    silentMs = 0
                    isHearing = true
                    onHearStart?()
                }
            } else {
                voiced = 0
            }
        } else {
            captured.append(contentsOf: frame)
            utteranceMs += frameMs
            if rms < endRMS {
                silentMs += frameMs
                if silentMs >= endSilenceMs { endUtterance() }
            } else {
                silentMs = 0
            }
        }
    }

    private func resetVad() {
        inUtterance = false
        voiced = 0
        silentMs = 0
        utteranceMs = 0
        captured = []
        preroll = []
    }

    private func endUtterance() {
        let voicedMs = utteranceMs - silentMs
        let samples = captured
        resetVad()
        isHearing = false
        hold()
        guard voicedMs >= minUtteranceMs, !samples.isEmpty else { listen(); return }
        onUtterance?(Self.wav(samples, sampleRate: 16_000))
    }

    /// 她按了"我说完了":VAD 正在攒的优先;VAD 哑了就用滚动缓冲最近 12 秒;缓冲里真没声音→返回 nil,界面要当场说是麦克风的问题
    func flushUtterance() -> Data? {
        var samples: [Float]
        if inUtterance, !captured.isEmpty { samples = captured } else { samples = rolling.suffix(60).flatMap { $0 } }   // 60 帧≈16k*4096/48k 每帧≈1365 样本 → 约 5 秒;取最近的
        resetVad(); isHearing = false; hold()
        var energy: Float = 0
        for v in samples { energy += v * v }
        let rms = samples.isEmpty ? 0 : (energy / Float(samples.count)).squareRoot()
        guard rms > 0.004 else { return nil }
        return Self.wav(samples, sampleRate: 16_000)
    }

    static func wav(_ samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put32(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put32(16); put16(1); put16(1)
        put32(UInt32(sampleRate)); put32(UInt32(sampleRate * 2)); put16(2); put16(16)
        data.append(contentsOf: Array("data".utf8)); put32(byteCount)
        data.reserveCapacity(data.count + samples.count * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let value = Int16(clamped < 0 ? clamped * 0x8000 : clamped * 0x7FFF)
            put16(UInt16(bitPattern: value))
        }
        return data
    }

    // MARK: 放他的声音

    func enqueue(_ url: URL) {
        queue.append(url)
        pump()
    }

    private func pump() {
        guard !playing, let next = queue.first else { return }
        queue.removeFirst()
        playing = true
        isSpeaking = true
        playGeneration += 1
        let generation = playGeneration
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: next)
                guard generation == playGeneration else { return }
                let player = try AVAudioPlayer(data: data)
                let box = PlayerDelegate { [weak self] in
                    Task { @MainActor in self?.finishedSegment(generation: generation) }
                }
                player.delegate = box
                delegateBox = box
                self.player = player
                player.prepareToPlay()
                if !player.play() { finishedSegment(generation: generation) }
            } catch {
                finishedSegment(generation: generation)
            }
        }
    }

    private func finishedSegment(generation: Int) {
        guard generation == playGeneration else { return }
        playing = false
        player = nil
        if queue.isEmpty { isSpeaking = false }
        pump()
    }

    /// 她插嘴:正在放的停、队列清空
    func bargeIn() {
        queue.removeAll()
        playGeneration += 1
        player?.stop()
        player = nil
        playing = false
        isSpeaking = false
    }

    var isPlaybackIdle: Bool { !playing && queue.isEmpty }

    func stopAll() {
        bargeIn()
        stopMic()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let done: () -> Void
    init(done: @escaping () -> Void) { self.done = done }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { done() }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) { done() }
}

/// 音频线程上的重采样器:把麦克风原生格式(48k/44.1k)转成 16k 单声道 float。普通类,不挂 actor。
final class ResamplePipe {
    let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?

    func prepare(from format: AVAudioFormat) {
        converter = AVAudioConverter(from: format, to: outFormat)
    }

    func downsample(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let converter else { return nil }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData, out.frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
    }
}
