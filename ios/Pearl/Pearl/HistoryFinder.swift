import Foundation
import SwiftUI

struct HistoryPagingButton: View {
    @EnvironmentObject private var theme: Theme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(theme.font(.metadata))
            .foregroundStyle(theme.metaText)
            .padding(.vertical, Theme.Metric.standard)
    }
}

struct SearchHighlight: ViewModifier {
    @EnvironmentObject private var theme: Theme
    let active: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius)
                    .stroke(theme.accent, lineWidth: Theme.Metric.highlightLine)
                    .padding(-Theme.Metric.small)
            }
        }
    }
}

struct HistoryFinder: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: Theme
    @ObservedObject var model: ChatViewModel
    @State private var query = ""
    @State private var date = Date()
    @State private var hits: [SearchHit] = []
    @State private var busy = false
    @State private var error = ""
    private let api = ChatAPI()

    var body: some View {
        NavigationStack {
            List {
                Section("按日期") {
                    DatePicker("哪一天", selection: $date, in: ...Date(), displayedComponents: .date)
                    Button("跳到这一天") { Task { await jumpToDay() } }.disabled(busy)
                }
                if !hits.isEmpty {
                    Section("聊天记录") {
                        ForEach(hits) { hit in
                            Button {
                                Task { await model.jump(to: hit.id); dismiss() }
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Metric.small) {
                                    Text(hit.role == "user" ? "你" : "他")
                                        .font(theme.font(.metadata))
                                        .foregroundStyle(theme.metaText)
                                    (Text(hit.before).foregroundColor(theme.thinkText)
                                     + Text(hit.match).foregroundColor(theme.bubbleText).bold()
                                     + Text(hit.after).foregroundColor(theme.thinkText))
                                        .font(theme.font(.cardBody))
                                        .lineLimit(3)
                                    Text(hit.date, format: .dateTime.year().month().day().hour().minute())
                                        .font(theme.font(.metadata))
                                        .foregroundStyle(theme.thinkLabel)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !error.isEmpty {
                    Text(error).font(theme.font(.metadata)).foregroundStyle(theme.warning)
                }
            }
            .overlay { if busy { ProgressView().tint(theme.accent) } }
            .navigationTitle("翻旧话")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜聊天原文")
            .onSubmit(of: .search) { Task { await search() } }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("关上") { dismiss() } }
            }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        busy = true
        defer { busy = false }
        do { hits = try await api.search(q).hits; error = "" }
        catch { self.error = error.localizedDescription }
    }

    private func jumpToDay() async {
        busy = true
        defer { busy = false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            let id = try await api.firstMessage(on: formatter.string(from: date))
            await model.jump(to: id, startOfDay: true)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
