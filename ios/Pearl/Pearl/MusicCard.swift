import Foundation
import SwiftUI

struct MusicCard: View {
    @EnvironmentObject private var theme: Theme
    let music: MusicInfo

    var body: some View {
        Link(destination: music.url) {
            HStack(spacing: Theme.Metric.roomy) {
                DownsampledAsyncImage(url: music.cover, maxPixel: 160) { image in
                    image.resizable().scaledToFill()
                } placeholder: { _ in theme.panelFill() }
                .frame(width: Theme.Metric.musicCover, height: Theme.Metric.musicCover)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.thumbnailRadius, style: .continuous))
                VStack(alignment: .leading, spacing: Theme.Metric.tiny) {
                    Text(music.name).font(theme.font(.cardTitle)).lineLimit(1)
                    Text(music.artist).font(theme.font(.cardBody)).foregroundStyle(theme.metaText).lineLimit(1)
                    if !music.note.isEmpty {
                        Text(music.note).font(theme.font(.metadata)).foregroundStyle(theme.thinkText).lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "play.fill")
                    .frame(width: Theme.Metric.cardIcon, height: Theme.Metric.cardIcon)
                    .background(theme.accent.opacity(0.14), in: Circle())
            }
            .foregroundStyle(theme.bubbleText)
            .padding(Theme.Metric.standard)
            .background(theme.embeddedCardFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("播放 \(music.name)，\(music.artist)")
    }
}
