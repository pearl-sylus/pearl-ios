import SwiftUI

struct WriteCard: View {
    @EnvironmentObject private var theme: Theme
    let presentation: ToolPresentation
    @State private var showDetail = false

    var body: some View {
        Group {
            if let url = presentation.url {
                Link(destination: url) { face }
            } else {
                Button { showDetail = true } label: { face }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            WriteCardDetail(label: presentation.label, content: presentation.detail)
        }
    }

    private var face: some View {
        HStack(alignment: .top, spacing: Theme.Metric.large) {
            Image(systemName: icon)
                .frame(width: Theme.Metric.cardIcon, height: Theme.Metric.cardIcon)
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: Theme.Metric.small) {
                Text(presentation.label).font(theme.font(.cardTitle))
                Text(presentation.detail)
                    .font(theme.font(.cardBody))
                    .foregroundStyle(theme.thinkText)
                    .lineLimit(3)
            }
            Spacer()
        }
        .foregroundStyle(theme.bubbleText)
        .padding(Theme.Metric.large)
        .background(theme.cardSolid.opacity(theme.glassAlpha),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
        .frame(maxWidth: Theme.Metric.cardMaxWidth)
    }

    private var icon: String {
        if presentation.label.contains("信") { return "envelope" }
        if presentation.label.contains("便签") { return "note.text" }
        if presentation.label.contains("日记") { return "book.closed" }
        return "heart.text.square"
    }
}

struct WriteCardDetail: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: Theme
    let label: String
    let content: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metric.section) {
                    Label(label, systemImage: "heart")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.metaText)
                    Text(content)
                        .font(theme.font(.bubble))
                        .lineSpacing(theme.bubbleLineSpacing)
                        .foregroundStyle(theme.bubbleText)
                        .textSelection(.enabled)
                }
                .padding(Theme.Metric.detailPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ChatBackground())
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("关上") { dismiss() } }
            }
        }
    }
}
