import Foundation
import SwiftUI

struct MusicCard: View {
    @EnvironmentObject private var theme: Theme
    let music: MusicInfo

    var body: some View {
        Link(destination: music.url) {
            HStack(spacing: Theme.Metric.roomy) {
                AsyncImage(url: music.cover) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        theme.panelFill()
                    }
                }
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
