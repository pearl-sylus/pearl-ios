import Foundation
import HealthKit
import SwiftUI
import WebKit

private struct HealthSnapshot: Encodable {
    let date: String
    let steps: Int?
    let heartRateAverage: Double?
    let heartRateMinimum: Double?
    let heartRateMaximum: Double?
    let hrv: Double?
    let bodyTemperature: Double?
    let sleepStarts: [String]?
    let sleepEnds: [String]?
    let isPeriod: Bool

    var hasData: Bool {
        steps != nil || heartRateAverage != nil || hrv != nil || bodyTemperature != nil
            || sleepStarts != nil || isPeriod
    }

    enum CodingKeys: String, CodingKey {
        case date, steps, hrv
        case heartRateAverage = "heart_rate_avg"
        case heartRateMinimum = "heart_rate_min"
        case heartRateMaximum = "heart_rate_max"
        case bodyTemperature = "body_temperature"
        case sleepStarts = "sleep_start"
        case sleepEnds = "sleep_end"
        case isPeriod = "is_period"
    }
}

private enum HealthSyncError: LocalizedError {
    case unavailable
    case noData
    case needsLogin
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "这台设备不支持 Apple 健康。"
        case .noData: return "还没有读到可同步的数据，请检查健康权限。"
        case .needsLogin: return "先去「家」里的工程台登录一次，再回来连接。"
        case .rejected(let message): return message
        }
    }
}

@MainActor
final class HealthProbeModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var isEnabled: Bool
    @Published private(set) var lastSynced: Date?
    @Published var message = "你允许后，他才能看见你的身体状态。"

    private let store = HKHealthStore()
    private let enabledKey = "healthSharing.enabled"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = HealthSyncError.unavailable.localizedDescription
            return
        }
        guard !isLoading else { return }
        isLoading = true
        message = "正在等你允许 Apple 健康…"
        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.isLoading = false
                    self.message = "没有连接成功：\(error.localizedDescription)"
                    return
                }
                await self.sync(markEnabled: true)
            }
        }
    }

    func syncIfEnabled() async {
        guard isEnabled, !isLoading else { return }
        isLoading = true
        await sync(markEnabled: false)
    }

    func stopSharing() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        message = "已停止自动同步。Apple 健康里的原数据没有改变。"
    }

    private var readTypes: Set<HKObjectType> {
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .stepCount, .heartRate, .heartRateVariabilitySDNN, .bodyTemperature
        ]
        var types = Set<HKObjectType>()
        for identifier in quantityIDs {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) { types.insert(type) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let period = HKObjectType.categoryType(forIdentifier: .menstrualFlow) { types.insert(period) }
        return types
    }

    private func sync(markEnabled: Bool) async {
        defer { isLoading = false }
        do {
            let snapshot = try await readSnapshot()
            guard snapshot.hasData else { throw HealthSyncError.noData }
            try await upload(snapshot)
            if markEnabled {
                isEnabled = true
                UserDefaults.standard.set(true, forKey: enabledKey)
            }
            lastSynced = Date()
            message = "同步好了，他现在能看见你的最新状态。"
        } catch {
            message = error.localizedDescription
        }
    }

    private func readSnapshot() async throws -> HealthSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today)!
        let heartUnit = HKUnit.count().unitDivided(by: .minute())
        let sleep = try await sleepSegments(from: yesterday, to: now)

        return HealthSnapshot(
            date: DateFormatter.healthDate.string(from: now),
            steps: try await quantity(.stepCount, unit: .count(), kind: .sum, from: today, to: now).map { Int($0.rounded()) },
            heartRateAverage: try await quantity(.heartRate, unit: heartUnit, kind: .average, from: today, to: now),
            heartRateMinimum: try await quantity(.heartRate, unit: heartUnit, kind: .minimum, from: today, to: now),
            heartRateMaximum: try await quantity(.heartRate, unit: heartUnit, kind: .maximum, from: today, to: now),
            hrv: try await quantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), kind: .average, from: yesterday, to: now),
            bodyTemperature: try await quantity(.bodyTemperature, unit: .degreeCelsius(), kind: .average, from: ninetyDaysAgo, to: now),
            sleepStarts: sleep.starts.isEmpty ? nil : sleep.starts,
            sleepEnds: sleep.ends.isEmpty ? nil : sleep.ends,
            isPeriod: try await hasPeriodSample(from: today, to: now)
        )
    }

    private enum StatisticKind {
        case sum, average, minimum, maximum

        var option: HKStatisticsOptions {
            switch self {
            case .sum: return .cumulativeSum
            case .average: return .discreteAverage
            case .minimum: return .discreteMin
            case .maximum: return .discreteMax
            }
        }
    }

    private func quantity(_ identifier: HKQuantityTypeIdentifier,
                          unit: HKUnit,
                          kind: StatisticKind,
                          from start: Date,
                          to end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: kind.option) { _, statistics, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                let value: HKQuantity?
                switch kind {
                case .sum: value = statistics?.sumQuantity()
                case .average: value = statistics?.averageQuantity()
                case .minimum: value = statistics?.minimumQuantity()
                case .maximum: value = statistics?.maximumQuantity()
                }
                continuation.resume(returning: value?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func sleepSegments(from start: Date, to end: Date) async throws -> (starts: [String], ends: [String]) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return ([], []) }
        let samples = try await categorySamples(type, from: start, to: end)
        let asleepValues = Set([
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])
        let asleep = samples.filter { asleepValues.contains($0.value) }.sorted { $0.startDate < $1.startDate }
        let formatter = ISO8601DateFormatter()
        return (asleep.map { formatter.string(from: $0.startDate) },
                asleep.map { formatter.string(from: $0.endDate) })
    }

    private func hasPeriodSample(from start: Date, to end: Date) async throws -> Bool {
        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return false }
        let samples = try await categorySamples(type, from: start, to: end)
        return !samples.isEmpty
    }

    private func categorySamples(_ type: HKCategoryType,
                                 from start: Date,
                                 to end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: nil) { _, samples, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }
    }

    private func upload(_ snapshot: HealthSnapshot) async throws {
        let cookies = await webCookies()
        let sessionCookie = cookies.first { $0.name == "wk" && $0.domain.contains("pearl-sylus.org") }
        guard let sessionCookie else { throw HealthSyncError.needsLogin }

        var request = URLRequest(url: URL(string: "/api/health/native", relativeTo: ChatAPI.baseURL)!.absoluteURL)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(sessionCookie.name)=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(snapshot)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 { throw HealthSyncError.needsLogin }
        guard (200..<300).contains(http.statusCode) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw HealthSyncError.rejected(object?["error"] as? String ?? "健康管道暂时没有收下。")
        }
    }

    private func webCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { continuation.resume(returning: $0) }
        }
    }
}

struct HealthProbeView: View {
    @ObservedObject var model: HealthProbeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: Theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metric.section) {
                    header

                    VStack(alignment: .leading, spacing: Theme.Metric.large) {
                        shareRow("heart.fill", "心率、HRV 与体温")
                        shareRow("figure.walk", "今天的步数")
                        shareRow("moon.zzz.fill", "昨夜睡眠与经期状态")
                    }
                    .padding(Theme.Metric.section)
                    .background(theme.panelFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius)
                            .stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.hairline)
                    }

                    Button {
                        model.connect()
                    } label: {
                        HStack(spacing: Theme.Metric.standard) {
                            if model.isLoading { ProgressView().tint(theme.white) }
                            Text(model.isLoading ? "正在同步…" : model.isEnabled ? "现在同步给他" : "允许并同步给他")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Metric.small)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)

                    if model.isEnabled {
                        Button("停止自动同步") { model.stopSharing() }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(theme.warning)
                    }

                    Label("每次打开 Purr Den 时刷新；现有快捷指令继续负责后台补送。",
                          systemImage: "lock.fill")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.metaText)
                        .padding(.horizontal, Theme.Metric.small)
                }
                .padding(Theme.Metric.detailPadding)
            }
            .background(ChatBackground())
            .navigationTitle("身体连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(model.isLoading)
    }

    private var header: some View {
        HStack(spacing: Theme.Metric.large) {
            Image(systemName: model.isEnabled ? "heart.fill" : "heart")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(theme.white)
                .frame(width: 56, height: 56)
                .background((model.isEnabled ? theme.success : theme.accent).gradient,
                            in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius))

            VStack(alignment: .leading, spacing: Theme.Metric.small) {
                Text("让他看见你的状态")
                    .font(theme.font(.cardTitle))
                    .foregroundStyle(theme.bubbleText)
                Text(model.message)
                    .font(theme.font(.cardBody))
                    .foregroundStyle(theme.metaText)
                if let date = model.lastSynced {
                    Text("上次同步 \(date.formatted(date: .omitted, time: .shortened))")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.timestampText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.section)
        .background(theme.panelFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius)
                .stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.thinLine)
        }
    }

    private func shareRow(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(theme.font(.cardBody)).foregroundStyle(theme.bubbleText)
        } icon: {
            Image(systemName: symbol).foregroundStyle(theme.accent)
        }
    }
}

private extension DateFormatter {
    static let healthDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
