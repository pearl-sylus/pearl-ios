import SwiftUI

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
                    theme.bubbleFill(mine: mine)
                    if theme.glassEnabled { theme.shine(for: scheme) }
                }
                .clipShape(shape)
            }
            .overlay {
                shape.stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.thinLine)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: Theme.Metric.bubbleMaxWidth, alignment: mine ? .trailing : .leading)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius, style: .continuous)
    }
}
