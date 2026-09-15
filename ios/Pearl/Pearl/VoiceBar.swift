import AVFoundation
import SwiftUI

struct VoiceBar: View {
    @EnvironmentObject private var theme: Theme
    @StateObject private var player: RemoteAudioPlayer
    let seconds: Int?
    let mine: Bool

    init(url: URL, seconds: Int?, mine: Bool) {
        _player = StateObject(wrappedValue: RemoteAudioPlayer(url: url))
        self.seconds = seconds
        self.mine = mine
    }

    var body: some View {
        Button { player.toggle() } label: {
            HStack(spacing: Theme.Metric.standard) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: Theme.Metric.voiceControl, height: Theme.Metric.voiceControl)
                    .background(theme.voiceControlFill(mine: mine), in: Circle())
                HStack(alignment: .center, spacing: Theme.Metric.tiny) {
                    ForEach(Array(Theme.Metric.voiceBars.enumerated()), id: \.offset) { index, height in
                        Capsule()
                            .fill(theme.voiceForeground(mine: mine))
                            .frame(width: Theme.Metric.waveWidth,
                                   height: player.isPlaying && index.isMultiple(of: 2) ? height * 0.65 : height)
                    }
                }
                if let seconds, seconds > 0 {
                    Text("\(seconds)″").font(theme.font(.metadata)).monospacedDigit()
                }
            }
            .foregroundStyle(theme.voiceForeground(mine: mine))
            .padding(.horizontal, Theme.Metric.roomy)
            .padding(.vertical, Theme.Metric.compact)
            .frame(minWidth: Theme.Metric.voiceMinWidth, alignment: .leading)
            .background(theme.voiceFill(mine: mine), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "暂停语音" : "播放语音")
    }
}

@MainActor
private final class RemoteAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    private let player: AVPlayer
    private var token: NSObjectProtocol?

    init(url: URL) {
        player = AVPlayer(url: url)
        token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }

    func toggle() {
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }
}
