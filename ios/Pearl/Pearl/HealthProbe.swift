import Foundation
import HealthKit
import SwiftUI

final class HealthProbeModel: ObservableObject {
    @Published var isLoading = false
    @Published var message = "Purr Den 只会读取你亲自允许的数据。"
    @Published var rows: [String] = []

    private let store = HKHealthStore()

    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "这台设备不支持 Apple 健康。"
            return
        }

        isLoading = true
        message = "正在等待你的授权…"
        rows = []

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

            var result: [String] = []
            let steps = try await sum(.stepCount, unit: .count(), from: today, to: now)
            result.append("今日步数：\(steps.map { String(Int($0.rounded())) } ?? "暂无数据")")

            let heartRate = try await average(.heartRate,
                                              unit: HKUnit.count().unitDivided(by: .minute()),
                                              from: today,
                                              to: now)
            result.append("今日平均心率：\(number(heartRate, suffix: " 次/分"))")

            let hrv = try await average(.heartRateVariabilitySDNN,
                                        unit: .secondUnit(with: .milli),
                                        from: yesterday,
                                        to: now)
            result.append("最近 HRV：\(number(hrv, suffix: " 毫秒"))")

            let temperature = try await average(.bodyTemperature,
                                                unit: .degreeCelsius(),
                                                from: ninetyDaysAgo,
                                                to: now)
            result.append("体温：\(number(temperature, suffix: " ℃", decimals: 1))")
            result.append("睡眠：\(try await latestSleep(from: yesterday, to: now))")
            result.append("经期：\(try await latestPeriod(from: ninetyDaysAgo, to: now))")

            await MainActor.run {
                self.rows = result
                self.message = "连接成功。这些数据目前只显示在你的手机上。"
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.red)

                Text("连接 Apple 健康")
                    .font(.title2.bold())
                Text(model.message)
                    .foregroundStyle(.secondary)

                ForEach(model.rows, id: \.self) { row in
                    Label(row, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                }

                Spacer()

                if model.rows.isEmpty {
                    Button {
                        model.connect()
                    } label: {
                        HStack {
                            if model.isLoading { ProgressView().tint(.white) }
                            Text(model.isLoading ? "正在连接…" : "连接 Apple 健康")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)
                } else {
                    Button("完成") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }

                Button("暂时跳过") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .disabled(model.isLoading)
            }
            .padding(24)
            .navigationTitle("健康测试")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(model.isLoading)
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
