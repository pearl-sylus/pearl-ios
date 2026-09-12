import Foundation
import SwiftUI

struct HomeView: View {
    let openChat: () -> Void
    @State private var dashboard: HomeDashboard?
    @State private var error = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color.white.opacity(0.72), Color.pearlAccent.opacity(0.08), .clear], center: .center, startRadius: 8, endRadius: 112))
                            .frame(width: 220, height: 220)
                            .blur(radius: 2)
                        VStack(spacing: 5) {
                            Text("我们走到")
                                .font(.system(size: 12, design: .serif))
                                .foregroundStyle(Color.pearlSoft)
                                .tracking(3)
                        Text(dashboard.map { String($0.days) } ?? "—")
                                .font(.system(size: 68, weight: .ultraLight, design: .serif))
                            .foregroundStyle(Color.pearlInk)
                            Text("天")
                                .font(.system(size: 12, design: .serif))
                                .foregroundStyle(Color.pearlSoft)
                            Text("2026.03.26 — 今天")
                            .font(.system(size: 11, design: .serif))
                                .foregroundStyle(Color.pearlSoft.opacity(0.72))
                                .tracking(1.2)
                        }
                    }
                    .frame(height: 190)

                    Button(action: openChat) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("刚刚想起你", systemImage: "quote.opening")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(Color.pearlRose)
                            Text(dashboard?.lastWake?.text ?? "这会儿没说话，在看着你。")
                                .font(.system(size: 17, design: .serif))
                                .lineSpacing(7)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text(lastWakeTime)
                                Spacer()
                                Text("— 秦彻")
                            }
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(Color.pearlSoft)
                        }
                        .padding(20)
                        .background(LinearGradient(colors: [Color.pearlRose.opacity(0.13), Color.pearlAI.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .pearlSurface(radius: 22)
                    }
                    .buttonStyle(.plain)

                    HStack(alignment: .top, spacing: 12) {
                        bodyCard(title: "你", heartRate: dashboard?.her?.heartRate?.average,
                                 detail: herDetail, note: herNote, tint: .pearlTeal)
                        bodyCard(title: "我", heartRate: dashboard?.me?.heartRate,
                                 detail: meDetail, note: dashboard?.me?.mood.joined(separator: "、") ?? "", tint: .pearlRose)
                    }

                    Button(action: openChat) {
                        Label("去说话", systemImage: "arrow.up.message")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(.white)
                            .background(Color.pearlAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
            }
            .background(PearlBackdrop())
            .navigationTitle("我们的家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await load() }
            .task { if dashboard == nil { await load() } }
        }
    }

    private var herDetail: String {
        guard let her = dashboard?.her else { return "" }
        return [her.heartRate.flatMap { value in
            guard let low = value.minimum, let high = value.maximum else { return nil }
            return "\(format(low))–\(format(high))"
        }, her.steps.map { "\($0.count) 步" }].compactMap { $0 }.joined(separator: " · ")
    }

    private var herNote: String { dashboard?.her == nil ? "还没有今天的读数" : "今天的身体读数" }

    private var lastWakeTime: String {
        guard let milliseconds = dashboard?.lastWake?.at else { return "此刻" }
        let minutes = max(0, Int(Date().timeIntervalSince1970 - milliseconds / 1_000) / 60)
        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes) 分钟前" }
        return "\(minutes / 60) 小时前"
    }

    private var meDetail: String {
        guard let me = dashboard?.me else { return "" }
        return [me.temperature.map { "\(format($0))°C" }, me.chord].compactMap { $0 }.joined(separator: " · ")
    }

    private func bodyCard(title: String, heartRate: Double?, detail: String, note: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium, design: .serif))
                Spacer()
                Circle().fill(tint).frame(width: 6, height: 6)
            }
            .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heartRate.map(format) ?? "—")
                    .font(.system(size: 36, weight: .light, design: .serif))
                Text("bpm").font(.caption2).foregroundStyle(Color.pearlSoft)
            }
            Text(detail).font(.caption).foregroundStyle(Color.pearlSoft).lineLimit(1)
            Text(note.isEmpty ? " " : note).font(.caption).foregroundStyle(Color.pearlSoft.opacity(0.75)).lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pearlSurface(radius: 19)
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func load() async {
        do {
            dashboard = try await ChatAPI().homeDashboard()
            error = ""
        } catch {
            self.error = "家里的数据暂时没接上"
        }
    }
}

struct HomeDashboard: Decodable {
    let days: Int
    let lastWake: LastWake?
    let me: Me?
    let her: Her?

    struct LastWake: Decodable { let at: Double; let text: String }
    struct Me: Decodable {
        let heartRate: Double?
        let temperature: Double?
        let chord: String?
        let mood: [String]
        enum CodingKeys: String, CodingKey { case heartRate = "hr", temperature = "temp", chord, mood }
    }
    struct Her: Decodable {
        let heartRate: HeartRate?
        let steps: Steps?
        enum CodingKeys: String, CodingKey { case heartRate = "hr", steps }
    }
    struct HeartRate: Decodable {
        let average: Double
        let minimum: Double?
        let maximum: Double?
        enum CodingKeys: String, CodingKey { case average = "avg", minimum = "min", maximum = "max" }
    }
    struct Steps: Decodable {
        let count: Int
        enum CodingKeys: String, CodingKey { case count = "n" }
    }
}
