import SwiftUI

struct AlbumRef: View {
    @EnvironmentObject private var theme: Theme
    let images: [String]
    let album: AlbumMeta?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metric.standard) {
            if let album {
                Label("相册\(album.title.map { "《\($0)》" } ?? "")", systemImage: "photo.on.rectangle")
                    .font(theme.font(.metadata))
                    .foregroundStyle(theme.metaText)
                    .padding(.horizontal, Theme.Metric.standard)
                    .padding(.vertical, Theme.Metric.small)
                    .background(theme.embeddedCardFill(), in: Capsule())
            }
            ForEach(images, id: \.self) { name in
                AsyncImage(url: ChatAPI.mediaURL(name)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        Label("图片没加载出来", systemImage: "photo.badge.exclamationmark")
                            .font(theme.font(.metadata))
                            .foregroundStyle(theme.warning)
                            .frame(maxWidth: .infinity, minHeight: Theme.Metric.imageErrorHeight)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Metric.imageRadius)
                            .fill(theme.cardSolid)
                            .frame(height: Theme.Metric.imagePlaceholderHeight)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.imageRadius, style: .continuous))
            }
        }
    }
}
