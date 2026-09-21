import Foundation
import HealthKit
import SwiftUI

struct HealthMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let symbol: String
}

final class HealthProbeModel: ObservableObject {
    @Published var isLoading = false
    @Published var message = "只读取你亲自允许的数据。"
    @Published var rows: [HealthMetric] = []
    @Published var lastUpdated: Date?

    private let store = HKHealthStore()

    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "这台设备不支持 Apple 健康。"
            return
        }

        isLoading = true
        message = "正在等待你的授权…"

        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.message = "没有连接成功：\(error.localizedDescription)"
                }
                return
            }

            Task { await self.readSummary() }
        }
    }

    private var readTypes: Set<HKObjectType> {
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .heartRate,
            .heartRateVariabilitySDNN,
            .bodyTemperature
        ]
        var types = Set<HKObjectType>()
        for identifier in quantityIDs {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) { types.insert(type) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let period = HKObjectType.categoryType(forIdentifier: .menstrualFlow) { types.insert(period) }
        return types
    }

    private func readSummary() async {
        do {
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today)!

            var result: [HealthMetric] = []
            let steps = try await sum(.stepCount, unit: .count(), from: today, to: now)
            result.append(HealthMetric(
                id: "steps",
                title: "今日步数",
                value: steps.map { String(Int($0.rounded())) } ?? "暂无数据",
                symbol: "figure.walk"
            ))

            let heartRate = try await average(.heartRate,
                                              unit: HKUnit.count().unitDivided(by: .minute()),
                                              from: today,
                                              to: now)
            result.append(HealthMetric(
                id: "heart",
                title: "平均心率",
                value: number(heartRate, suffix: " 次/分"),
                symbol: "heart.fill"
            ))

            let hrv = try await average(.heartRateVariabilitySDNN,
                                        unit: .secondUnit(with: .milli),
                                        from: yesterday,
                                        to: now)
            result.append(HealthMetric(
                id: "hrv",
                title: "最近 HRV",
                value: number(hrv, suffix: " 毫秒"),
                symbol: "waveform.path.ecg"
            ))

            let temperature = try await average(.bodyTemperature,
                                                unit: .degreeCelsius(),
                                                from: ninetyDaysAgo,
                                                to: now)
            result.append(HealthMetric(
                id: "temperature",
                title: "体温",
                value: number(temperature, suffix: " ℃", decimals: 1),
                symbol: "thermometer.medium"
            ))
            result.append(HealthMetric(
                id: "sleep",
                title: "昨夜睡眠",
                value: try await latestSleep(from: yesterday, to: now),
                symbol: "moon.zzz.fill"
            ))
            result.append(HealthMetric(
                id: "period",
                title: "最近经期",
                value: try await latestPeriod(from: ninetyDaysAgo, to: now),
                symbol: "drop.fill"
            ))

            await MainActor.run {
                self.rows = result
                self.lastUpdated = now
                self.message = "已从这台 iPhone 读取。"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.message = "已经连接，但读取时出错：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier,
                     unit: HKUnit,
                     from start: Date,
                     to end: Date) async throws -> Double? {
        try await statistic(identifier, option: .cumulativeSum, unit: unit, from: start, to: end)
    }

    private func average(_ identifier: HKQuantityTypeIdentifier,
                         unit: HKUnit,
                         from start: Date,
                         to end: Date) async throws -> Double? {
        try await statistic(identifier, option: .discreteAverage, unit: unit, from: start, to: end)
    }

    private func statistic(_ identifier: HKQuantityTypeIdentifier,
                           option: HKStatisticsOptions,
                           unit: HKUnit,
                           from start: Date,
                           to end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: option) { _, statistics, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                let quantity = option == .cumulativeSum
                    ? statistics?.sumQuantity()
                    : statistics?.averageQuantity()
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func latestSleep(from start: Date, to end: Date) async throws -> String {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return "暂无数据" }
        let samples = try await categorySamples(type, from: start, to: end)
        let asleepValues = Set([
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])
        let asleep = samples.filter { asleepValues.contains($0.value) }
        guard let first = asleep.map(\.startDate).min(),
              let last = asleep.map(\.endDate).max() else { return "暂无数据" }
        return "\(time(first))–\(time(last))"
    }

    private func latestPeriod(from start: Date, to end: Date) async throws -> String {
        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return "暂无数据" }
        let samples = try await categorySamples(type, from: start, to: end)
        guard let latest = samples.max(by: { $0.startDate < $1.startDate }) else { return "暂无数据" }
        return DateFormatter.healthDay.string(from: latest.startDate)
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
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }
    }

    private func number(_ value: Double?, suffix: String, decimals: Int = 0) -> String {
        guard let value else { return "暂无数据" }
        return String(format: "%.*f", decimals, value) + suffix
    }

    private func time(_ date: Date) -> String {
        DateFormatter.healthTime.string(from: date)
    }
}

struct HealthProbeView: View {
    @ObservedObject var model: HealthProbeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: Theme

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metric.section) {
                    header

                    if !model.rows.isEmpty {
                        LazyVGrid(columns: columns, spacing: Theme.Metric.standard) {
                            ForEach(model.rows) { metric in
                                metricCard(metric)
                            }
                        }
                    }

                    Button {
                        model.connect()
                    } label: {
                        HStack(spacing: Theme.Metric.standard) {
                            if model.isLoading { ProgressView().tint(.white) }
                            Text(model.isLoading ? "正在读取…" : model.rows.isEmpty ? "连接 Apple 健康" : "刷新数据")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Metric.small)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)

                    Label("数据留在这台手机上；后台同步仍由你现有的快捷指令负责。",
                          systemImage: "lock.fill")
                        .font(theme.font(.metadata))
                        .foregroundStyle(theme.metaText)
                        .padding(.horizontal, Theme.Metric.small)
                }
                .padding(Theme.Metric.detailPadding)
            }
            .background(ChatBackground())
            .navigationTitle("身体")
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
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(theme.white)
                .frame(width: 56, height: 56)
                .background(theme.warning.gradient, in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius))

            VStack(alignment: .leading, spacing: Theme.Metric.small) {
                Text("Apple 健康")
                    .font(theme.font(.cardTitle))
                    .foregroundStyle(theme.bubbleText)
                Text(model.message)
                    .font(theme.font(.cardBody))
                    .foregroundStyle(theme.metaText)
                if let date = model.lastUpdated {
                    Text("更新于 \(date.formatted(date: .omitted, time: .shortened))")
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

    private func metricCard(_ metric: HealthMetric) -> some View {
        VStack(alignment: .leading, spacing: Theme.Metric.standard) {
            Image(systemName: metric.symbol)
                .font(theme.font(.control).weight(.semibold))
                .foregroundStyle(metric.id == "heart" ? theme.warning : theme.accent)
            Text(metric.title)
                .font(theme.font(.metadata))
                .foregroundStyle(theme.metaText)
            Text(metric.value)
                .font(theme.font(.cardTitle))
                .foregroundStyle(theme.bubbleText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(Theme.Metric.large)
        .background(theme.panelFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Metric.cardRadius)
                .stroke(theme.rim(for: scheme), lineWidth: Theme.Metric.hairline)
        }
    }
}

private extension DateFormatter {
    static let healthTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let healthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter
    }()
}
