import SwiftUI
import UIKit

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
                if theme.glassEnabled && theme.glassBlur > 0 {
                    GlassBlur(intensity: theme.glassBlur / 40)
                }
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

private struct GlassBlur: UIViewRepresentable {
    let intensity: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        context.coordinator.update(view, intensity: intensity)
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        context.coordinator.update(view, intensity: intensity)
    }

    static func dismantleUIView(_ view: UIVisualEffectView, coordinator: Coordinator) {
        coordinator.animator?.stopAnimation(true)
    }

    final class Coordinator {
        var animator: UIViewPropertyAnimator?
        private var intensity = -1.0

        func update(_ view: UIVisualEffectView, intensity next: Double) {
            let next = min(1, max(0, next))
            guard abs(next - intensity) > 0.001 else { return }
            intensity = next
            animator?.stopAnimation(true)
            view.effect = nil
            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
                view.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
            animator.fractionComplete = next
            self.animator = animator
        }
    }
}
