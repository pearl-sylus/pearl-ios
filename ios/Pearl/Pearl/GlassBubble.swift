import SwiftUI
import UIKit

struct GlassBubble<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: Theme

    let mine: Bool
    private let content: Content

    init(mine: Bool, @ViewBuilder content: () -> Content) {
        self.mine = mine
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, Theme.Metric.bubbleHorizontal)
            .padding(.vertical, Theme.Metric.roomy)
            .background {
                ZStack {
                    if theme.glassEnabled && theme.glassBlur > 0 {
                        GlassBlur(intensity: theme.glassBlur / 40)
                    }
                    theme.bubbleFill(mine: mine)
                    if theme.glassEnabled { theme.shine(for: scheme) }
                }
                .clipShape(shape)
            }
            .overlay {
                shape.stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.thinLine)
            }
            .shadow(color: theme.primaryShadow(for: scheme),
                    radius: Theme.Metric.shadowRadius,
                    y: Theme.Metric.shadowY)
            .shadow(color: theme.secondaryShadow(for: scheme),
                    radius: Theme.Metric.smallShadowRadius,
                    y: Theme.Metric.smallShadowY)
            .frame(maxWidth: Theme.Metric.bubbleMaxWidth, alignment: mine ? .trailing : .leading)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius, style: .continuous)
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
                view.effect = UIBlurEffect(style: .systemMaterial)
            }
            animator.fractionComplete = next
            self.animator = animator
        }
    }
}
