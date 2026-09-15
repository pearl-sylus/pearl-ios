import SwiftUI

struct ThinkBlock: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: Theme

    let text: String
    let cut: String?
    @State private var expanded: Bool

    init(text: String, cut: String? = nil, startsOpen: Bool = false) {
        self.text = text
        self.cut = cut
        _expanded = State(initialValue: startsOpen)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: Theme.Metric.compact) {
                Text(text)
                    .font(theme.font(.thinkingBody))
                    .lineSpacing(theme.thinkingLineSpacing)
                    .foregroundStyle(theme.thinkText)
                    .textSelection(.enabled)
                Text(cutLabel)
                    .font(theme.font(.metadata))
                    .foregroundStyle(cutWarning ? theme.warning : theme.thinkLabel)
            }
            .padding(.horizontal, Theme.Metric.bubbleHorizontal)
            .padding(.vertical, Theme.Metric.roomy)
            .background(theme.thinkingFill(), in: shape)
            .overlay { shape.stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.thinLine) }
            .padding(.top, Theme.Metric.compact)
            .padding(.bottom, Theme.Metric.roomy)
        } label: {
            Text(cutWarning ? "✦ 他想过 ⚠" : "✦ 他想过")
                .font(theme.font(.thinkingLabel))
                .foregroundStyle(theme.metaText)
        }
        .frame(maxWidth: Theme.Metric.thinkMaxWidth, alignment: .leading)
        .tint(theme.metaText)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metric.thinkRadius, style: .continuous)
    }

    private var cutWarning: Bool { cut != nil && cut != "display" }
    private var cutLabel: String {
        switch cut {
        case "display": return "\(text.count)字 · 显示掉尾，他其实想完了"
        case "real": return "\(text.count)字 · 真没想完"
        case "max_tokens": return "\(text.count)字 · 被输出上限掐断"
        case .some(_): return "\(text.count)字 · 断尾了"
        case nil: return "\(text.count)字 · 收完了"
        }
    }
}
