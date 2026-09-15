import SwiftUI

struct ChatBackground: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: Theme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.background(for: scheme)
                wallpaper
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                theme.veilColor()
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var wallpaper: some View {
        if let name = theme.wallpaper.assetName {
            Image(name).resizable().scaledToFill()
        } else if theme.wallpaper == .custom, let image = theme.customWallpaperImage {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            theme.background(for: scheme)
        }
    }
}
