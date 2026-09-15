import SwiftUI

struct TarotCard: View {
    @EnvironmentObject private var theme: Theme
    let presentation: ToolPresentation
    @State private var showReading = false

    var body: some View {
        Group {
            if let url = presentation.url {
                Link(destination: url) { face }
            } else {
                Button { showReading = true } label: { face }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showReading) {
            WriteCardDetail(label: presentation.label, content: presentation.detail)
        }
    }

    private var face: some View {
        HStack(spacing: Theme.Metric.large) {
            ZStack {
                tarotBack(rotation: -8, offset: -Theme.Metric.small)
                tarotBack(rotation: 8, offset: Theme.Metric.small)
                RoundedRectangle(cornerRadius: Theme.Metric.compact, style: .continuous)
                    .fill(theme.accent)
                    .overlay(Image(systemName: "sparkles").foregroundStyle(theme.white))
            }
            .frame(width: Theme.Metric.tarotWidth, height: Theme.Metric.tarotHeight)
            VStack(alignment: .leading, spacing: Theme.Metric.small) {
                Text(presentation.label).font(theme.font(.cardTitle))
                Text(presentation.detail).font(theme.font(.cardBody)).foregroundStyle(theme.metaText).lineLimit(3)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(theme.thinkLabel)
        }
        .foregroundStyle(theme.bubbleText)
        .padding(Theme.Metric.large)
        .background(theme.cardSolid.opacity(theme.glassAlpha),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
        .frame(maxWidth: Theme.Metric.cardMaxWidth)
    }

    private func tarotBack(rotation: Double, offset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Theme.Metric.compact, style: .continuous)
            .fill(theme.tarotBack)
            .rotationEffect(.degrees(rotation))
            .offset(x: offset)
    }
}
