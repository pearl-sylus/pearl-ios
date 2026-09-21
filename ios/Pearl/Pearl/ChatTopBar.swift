import SwiftUI

struct ChatTopBar: View {
    @EnvironmentObject private var theme: Theme
    @ObservedObject var model: ChatViewModel
    let openHistory: () -> Void
    let openControls: () -> Void
    let openAppearance: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: Theme.Metric.tiny) {
                Text("慢慢说").font(theme.font(.navigationTitle)).foregroundStyle(theme.bubbleText)
                HStack(spacing: Theme.Metric.small) {
                    Circle()
                        .fill(model.error.isEmpty ? theme.accent : theme.warning)
                        .frame(width: Theme.Metric.small, height: Theme.Metric.small)
                    Text(model.status.isEmpty ? "你说，我听着。" : model.status)
                        .lineLimit(1)
                }
                .font(theme.font(.navigationSubtitle))
                .foregroundStyle(theme.metaText)
            }
            HStack {
                Button(action: openControls) { ContextGauge(value: model.contextPercent) }
                    .accessibilityLabel("聊天设置，记忆水位 \(model.contextPercent)%")
                Spacer()
                Button(action: openHistory) {
                    topButton("magnifyingglass")
                }
                .accessibilityLabel("搜索聊天")
                Button(action: openAppearance) {
                    topButton("paintpalette")
                }
                .accessibilityLabel("外观设置")
            }
        }
        .padding(.horizontal, Theme.Metric.chatHorizontal)
        .frame(height: Theme.Metric.topBarHeight)
        .background(theme.panelFill())
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.rim(for: .light)).frame(height: Theme.Metric.hairline)
        }
    }

    private func topButton(_ name: String) -> some View {
        Image(systemName: name)
            .font(theme.font(.control))
            .foregroundStyle(theme.accent)
            .frame(width: Theme.Metric.topButton, height: Theme.Metric.topButton)
            .background(theme.composerButtonFill, in: Circle())
    }
}

struct ContextGauge: View {
    @EnvironmentObject private var theme: Theme
    let value: Int

    var body: some View {
        ZStack {
            Circle().stroke(theme.gaugeTrack, lineWidth: Theme.Metric.gaugeLine)
            Circle()
                .trim(from: Theme.Metric.zero, to: CGFloat(value) / 100)
                .stroke(value > 82 ? theme.warning : theme.accent,
                        style: StrokeStyle(lineWidth: Theme.Metric.gaugeLine, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)").font(theme.font(.gauge)).foregroundStyle(theme.metaText)
        }
        .frame(width: Theme.Metric.gaugeSize, height: Theme.Metric.gaugeSize)
    }
}
