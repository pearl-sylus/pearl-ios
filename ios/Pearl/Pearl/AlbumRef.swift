import ImageIO
import SwiftUI
import UIKit

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
                DownsampledAsyncImage(url: ChatAPI.mediaURL(name), maxPixel: 1_280) { image in
                    image.resizable().scaledToFit()
                } placeholder: { failed in
                    if failed {
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

struct DownsampledAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let maxPixel: CGFloat
    let content: (Image) -> Content
    let placeholder: (Bool) -> Placeholder

    @State private var image: UIImage?
    @State private var failed = false

    init(
        url: URL?,
        maxPixel: CGFloat,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping (Bool) -> Placeholder
    ) {
        self.url = url
        self.maxPixel = maxPixel
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder(failed)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let url else { failed = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = await Task.detached(priority: .utility) {
                Self.downsample(data, maxPixel: maxPixel)
            }.value
            guard !Task.isCancelled else { return }
            image = decoded
            failed = decoded == nil
        } catch is CancellationError {
        } catch {
            failed = true
        }
    }

    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
