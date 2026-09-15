import SwiftUI

struct AlarmBlock: View {
    @EnvironmentObject private var theme: Theme
    let text: String
    var detail: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Metric.compact) {
            Image(systemName: "clock")
            Text([text, detail].filter { !$0.isEmpty }.joined(separator: " · "))
        }
        .font(theme.font(.thinkingLabel))
        .foregroundStyle(theme.metaText)
        .frame(maxWidth: Theme.Metric.stepMaxWidth, alignment: .leading)
        .padding(.leading, Theme.Metric.small)
        .accessibilityElement(children: .combine)
    }
}
