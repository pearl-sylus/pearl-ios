import Foundation
import SwiftUI

struct HomeView: View {
    let openChat: () -> Void
    @State private var dashboard: HomeDashboard?
    @State private var error = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        Text(dashboard.map { String($0.days) } ?? "—")
                            .font(.system(size: 58, weight: .thin, design: .serif))
                            .foregroundStyle(Color.pearlInk)
                        Text("天 · 从 2026 年 3 月 26 日开始")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(Color.pearlSoft)
                    }
                    .padding(.vertical, 12)

                    Button(action: openChat) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(dashboard?.lastWake?.text ?? "这会儿没说话，在看着你。")
                                .font(.system(size: 16, design: .serif))
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text("慢慢说")
                                Spacer()
                                Text("— 秦彻")
                            }
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(Color.pearlSoft)
                        }
                        .homeCard()
                    }
                    .buttonStyle(.plain)

                    HStack(alignment: .top, spacing: 12) {
                        bodyCard(title: "你", heartRate: dashboard?.her?.heartRate?.average,
                                 detail: herDetail, note: herNote)
                        bodyCard(title: "我", heartRate: dashboard?.me?.heartRate,
                                 detail: meDetail, note: dashboard?.me?.mood.joined(separator: "、") ?? "")
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
                    .padding(.top, 2)

                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(HomeBackground())
            .navigationTitle("家")
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

    private var meDetail: String {
        guard let me = dashboard?.me else { return "" }
        return [me.temperature.map { "\(format($0))°C" }, me.chord].compactMap { $0 }.joined(separator: " · ")
    }

    private func bodyCard(title: String, heartRate: Double?, detail: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(Color.pearlSoft)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heartRate.map(format) ?? "—")
                    .font(.system(size: 34, weight: .light, design: .serif))
                Text("bpm").font(.caption2).foregroundStyle(Color.pearlSoft)
            }
            Text(detail).font(.caption).foregroundStyle(Color.pearlSoft).lineLimit(1)
            Text(note.isEmpty ? " " : note).font(.caption).foregroundStyle(Color.pearlSoft.opacity(0.75)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
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

private struct HomeBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.pearlBackground
                AsyncImage(url: URL(string: "/assets/tidal-echo/chat-light.webp", relativeTo: ChatAPI.baseURL)?.absoluteURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .opacity(0.42)
                Color.white.opacity(0.12)
            }
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func homeCard() -> some View {
        padding(17)
            .foregroundStyle(Color.pearlInk)
            .background(Color.pearlAI, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.pearlLine, lineWidth: 0.7) }
            .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)
    }
}
