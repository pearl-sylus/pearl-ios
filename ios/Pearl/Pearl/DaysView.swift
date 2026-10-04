import Foundation
import SwiftUI

struct DaysView: View {
    @State private var response: DaysResponse?
    @State private var month = Date()
    @State private var selectedDate = ""
    @State private var filter = "全部"
    @State private var error = ""

    private let calendar = Calendar(identifier: .gregorian)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let filters = ["全部", "日记", "信", "feel", "murmur", "I", "核心"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    monthHeader
                    filterBar
                    calendarCard
                    selectedDay
                    if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
            .background(PearlBackdrop())
            .navigationTitle("日子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await load() }
            .task { if response == nil { await load() } }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 18) {
            monthButton("chevron.left", delta: -1)
            VStack(spacing: 3) {
                Text(month.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN"))))
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Color.pearlInk)
                Text("这个月留下了 \(monthMemoryCount) 条")
                    .font(.system(size: 10.5, design: .serif))
                    .foregroundStyle(Color.pearlSoft)
            }
            .frame(maxWidth: .infinity)
            monthButton("chevron.right", delta: 1)
        }
        .padding(.top, 12)
    }

    private func monthButton(_ icon: String, delta: Int) -> some View {
        Button { shiftMonth(delta) } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.pearlAI.opacity(0.7), in: Circle())
                .overlay { Circle().stroke(Color.pearlLine, lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.pearlInk)
        .disabled(!canShift(delta))
        .opacity(canShift(delta) ? 1 : 0.25)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(filters, id: \.self) { item in
                    Button(item) { filter = item }
                        .font(.system(size: 11.5, design: .serif))
                        .foregroundStyle(filter == item ? Color.white : Color.pearlSoft)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(filter == item ? Color.pearlAccent : Color.pearlAI.opacity(0.68), in: Capsule())
                        .overlay { Capsule().stroke(filter == item ? Color.clear : Color.pearlLine, lineWidth: 0.7) }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var calendarCard: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(weekdays, id: \.self) { day in
                Text(day).font(.system(size: 10, design: .serif)).foregroundStyle(Color.pearlSoft.opacity(0.7))
            }
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                if let date { dayCell(date) } else { Color.clear.frame(height: 43) }
            }
        }
        .padding(14)
        .pearlSurface(radius: 22)
    }

    private func dayCell(_ date: Date) -> some View {
        let key = Self.keyFormatter.string(from: date)
        let record = dayMap[key]
        let memories = filtered(record?.mem ?? [])
        let hasContent = !memories.isEmpty || (filter == "全部" && record?.body != nil)
        let selected = selectedDate == key
        let today = calendar.isDateInToday(date)
        return Button {
            if record != nil { selectedDate = key }
        } label: {
            VStack(spacing: 4) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.system(size: 13, weight: selected ? .semibold : .regular, design: .rounded))
                HStack(spacing: 2) {
                    ForEach(Array(Set(memories.map(\.bk))).sorted().prefix(4), id: \.self) { kind in
                        Circle().fill(bucketColor(kind)).frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(selected ? Color.white : hasContent ? Color.pearlInk : Color.pearlSoft.opacity(0.42))
            .frame(maxWidth: .infinity, minHeight: 43)
            .background(selected ? Color.pearlAccent : hasContent ? Color.pearlAI.opacity(0.70) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(today && !selected ? Color.pearlRose.opacity(0.7) : hasContent && !selected ? Color.pearlLine : Color.clear,
                            lineWidth: today ? 1.1 : 0.6)
            }
        }
        .buttonStyle(.plain)
        .disabled(record == nil)
        .accessibilityLabel("\(key)，\(memories.count) 条记录")
    }

    @ViewBuilder private var selectedDay: some View {
        if let day = dayMap[selectedDate] {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(dayTitle(day.date))
                        .font(.system(size: 19, weight: .medium, design: .serif))
                    Spacer()
                    Text(bodyLine(day.body))
                        .font(.system(size: 10.5, design: .serif))
                        .foregroundStyle(Color.pearlTeal)
                }
                ForEach(day.marks, id: \.text) { mark in
                    Label(mark.text, systemImage: "sparkle")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(Color.pearlRose)
                }
                let memories = filtered(day.mem)
                if memories.isEmpty {
                    Text("这一天没有留下这一类记录。")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Color.pearlSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(memories) { memory in memoryCard(memory) }
                }
            }
        } else if response != nil {
            Text("点亮着的日子，看看那天留下了什么。")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(Color.pearlSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    private func memoryCard(_ memory: DayMemory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule().fill(bucketColor(memory.bk)).frame(width: 3)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(memory.drawer.isEmpty ? memory.bucket : memory.drawer)
                        .font(.system(size: 10.5, weight: .medium, design: .serif))
                        .foregroundStyle(bucketColor(memory.bk))
                    Text(memory.time).font(.caption2.monospacedDigit()).foregroundStyle(Color.pearlSoft.opacity(0.7))
                }
                Text(memory.title)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Color.pearlInk)
                if !memory.gist.isEmpty {
                    Text(memory.gist)
                        .font(.system(size: 12.5, design: .serif))
                        .foregroundStyle(Color.pearlSoft)
                        .lineSpacing(4)
                        .lineLimit(5)
                }
                if !memory.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(memory.tags.prefix(5), id: \.self) { tag in
                                Text(tag).font(.system(size: 9.5, design: .serif))
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(bucketColor(memory.bk).opacity(0.09), in: Capsule())
                                    .foregroundStyle(bucketColor(memory.bk))
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .pearlSurface(radius: 17)
    }

    private var dayMap: [String: DayRecord] {
        Dictionary(uniqueKeysWithValues: (response?.days ?? []).map { ($0.date, $0) })
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) + 5) % 7
        let dates = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return Array(repeating: nil, count: leading) + dates.map(Optional.some)
    }

    private var monthMemoryCount: Int {
        let prefix = Self.monthFormatter.string(from: month)
        return (response?.days ?? []).filter { $0.date.hasPrefix(prefix) }.flatMap(\.mem).count
    }

    private func filtered(_ memories: [DayMemory]) -> [DayMemory] {
        switch filter {
        case "日记": return memories.filter { $0.drawer == "日记" }
        case "信": return memories.filter { $0.bk == "letter" || $0.drawer == "信箱" }
        case "feel": return memories.filter { $0.bk == "feel" }
        case "murmur": return memories.filter { $0.bk == "murmur" }
        case "I": return memories.filter { $0.bk == "self" || $0.bucket == "I" }
        case "核心": return memories.filter { $0.bk == "core" || ["核心", "规矩"].contains($0.drawer) }
        default: return memories
        }
    }

    private func bucketColor(_ key: String) -> Color {
        switch key {
        case "feel": return .pearlRose
        case "letter": return .pearlGold
        case "murmur": return .pearlTeal
        case "core": return .pearlLavender
        case "self": return .blue.opacity(0.72)
        default: return .pearlSoft
        }
    }

    private func bodyLine(_ body: DayBody?) -> String {
        guard let body else { return "" }
        return [body.heartRate.map { "心率 \(Int($0.average))" }, body.steps.map { "\($0) 步" }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func dayTitle(_ key: String) -> String {
        guard let date = Self.keyFormatter.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) { month = next }
        selectedDate = ""
    }

    private func canShift(_ delta: Int) -> Bool {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return false }
        let key = Self.monthFormatter.string(from: next)
        let earliest = String((response?.since ?? "2026-03-26").prefix(7))
        let latest = Self.monthFormatter.string(from: Date())
        return key >= earliest && key <= latest
    }

    private func load() async {
        do {
            let value = try await ChatAPI().days()
            response = value
            if selectedDate.isEmpty, let latest = value.days.first {
                selectedDate = latest.date
                month = Self.keyFormatter.date(from: latest.date) ?? Date()
            }
            error = ""
        } catch {
            self.error = "这些日子暂时没接上"
        }
    }

    private static let keyFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: "Asia/Shanghai"); value.dateFormat = "yyyy-MM-dd"; return value
    }()
    private static let monthFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: "Asia/Shanghai"); value.dateFormat = "yyyy-MM"; return value
    }()
}

struct DaysResponse: Decodable { let since: String; let days: [DayRecord] }
struct DayRecord: Decodable { let date: String; let mem: [DayMemory]; let body: DayBody?; let marks: [DayMark] }
struct DayMemory: Decodable, Identifiable {
    var id: String { rel }
    let bucket: String; let bk: String; let drawer: String; let tags: [String]
    let rel: String; let time: String; let title: String; let gist: String
}
struct DayBody: Decodable {
    let heartRate: DayHeartRate?; let steps: Int?
    enum CodingKeys: String, CodingKey { case heartRate = "hr", steps }
}
struct DayHeartRate: Decodable { let average: Double; enum CodingKeys: String, CodingKey { case average = "avg" } }
struct DayMark: Decodable { let text: String }
