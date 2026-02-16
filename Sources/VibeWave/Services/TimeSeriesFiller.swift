import Foundation

public final class TimeSeriesFiller {
    private static var localCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private static func startOfHourUTC(for date: Date) -> Date {
        let components = localCalendar.dateComponents([.year, .month, .day, .hour], from: date)
        return localCalendar.date(from: components) ?? date
    }

    private static func startOfDayUTC(for date: Date) -> Date {
        localCalendar.startOfDay(for: date)
    }

    private static func startOfMonthUTC(for date: Date) -> Date {
        let components = localCalendar.dateComponents([.year, .month], from: date)
        return localCalendar.date(from: components) ?? date
    }

    private static func toBucketMs(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private static func formatLabel(_ date: Date, timeRange: HistoryTimeRangeOption) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        switch timeRange {
        case .last24Hours:
            formatter.dateFormat = "H:00"
        case .last30Days:
            formatter.dateFormat = "M月d日"
        case .allTime:
            formatter.dateFormat = "yyyy年M月"
        }
        return formatter.string(from: date)
    }

    public static func last24HourWindowAnchoredToCurrentHour(
        reference: Date = Date(),
        barCount: Int = 24
    ) -> (start: Date, endExclusive: Date) {
        let safeBarCount = max(1, barCount)
        let currentHourStart = startOfHourUTC(for: reference)
        let start = localCalendar.date(byAdding: .hour, value: -(safeBarCount - 1), to: currentHourStart) ?? currentHourStart
        let endExclusive = localCalendar.date(byAdding: .hour, value: 1, to: currentHourStart) ?? reference
        return (start: start, endExclusive: endExclusive)
    }

    public static func fillHourlyData(
        bucketValues: [Int64: Int],
        startTime: Date,
        barCount: Int = 24
    ) -> [InputTokensDataPoint] {
        let alignedStart = startOfHourUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .hour, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let tokenValue = bucketValues[bucketMs] ?? 0

            return InputTokensDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .last24Hours),
                totalTokens: tokenValue,
                segments: [],
                bucketIndex: index,
                hasData: tokenValue > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillDailyData(
        bucketValues: [Int64: Int],
        startTime: Date,
        barCount: Int = 30
    ) -> [InputTokensDataPoint] {
        let alignedStart = startOfDayUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .day, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let tokenValue = bucketValues[bucketMs] ?? 0

            return InputTokensDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .last30Days),
                totalTokens: tokenValue,
                segments: [],
                bucketIndex: index,
                hasData: tokenValue > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillMonthlyData(
        bucketValues: [Int64: Int],
        startTime: Date,
        barCount: Int = 12
    ) -> [InputTokensDataPoint] {
        let alignedStart = startOfMonthUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .month, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let tokenValue = bucketValues[bucketMs] ?? 0

            return InputTokensDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .allTime),
                totalTokens: tokenValue,
                segments: [],
                bucketIndex: index,
                hasData: tokenValue > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillHourlyData(
        existingData: [InputTokensDataPoint],
        endTime: Date
    ) -> [InputTokensDataPoint] {
        let nowStart = startOfDayUTC(for: endTime)
        let bucketValues = existingData.reduce(into: [Int64: Int]()) { partialResult, dataPoint in
            let bucket = toBucketMs(startOfHourUTC(for: Date(timeIntervalSince1970: dataPoint.timestamp)))
            partialResult[bucket, default: 0] += dataPoint.totalTokens
        }
        return fillHourlyData(bucketValues: bucketValues, startTime: nowStart, barCount: 24)
    }

    public static func fillDailyData(
        existingData: [InputTokensDataPoint],
        endTime: Date
    ) -> [InputTokensDataPoint] {
        let endDay = startOfDayUTC(for: endTime)
        let startDay = localCalendar.date(byAdding: .day, value: -29, to: endDay) ?? endDay
        let bucketValues = existingData.reduce(into: [Int64: Int]()) { partialResult, dataPoint in
            let bucket = toBucketMs(startOfDayUTC(for: Date(timeIntervalSince1970: dataPoint.timestamp)))
            partialResult[bucket, default: 0] += dataPoint.totalTokens
        }
        return fillDailyData(bucketValues: bucketValues, startTime: startDay, barCount: 30)
    }

    public static func fillMonthlyData(
        existingData: [InputTokensDataPoint],
        startTime: Date,
        endTime: Date
    ) -> [InputTokensDataPoint] {
        let startMonth = startOfMonthUTC(for: startTime)
        let endMonth = startOfMonthUTC(for: endTime)
        let monthDiff = max(0, localCalendar.dateComponents([.month], from: startMonth, to: endMonth).month ?? 0)
        let barCount = monthDiff + 1

        let bucketValues = existingData.reduce(into: [Int64: Int]()) { partialResult, dataPoint in
            let bucket = toBucketMs(startOfMonthUTC(for: Date(timeIntervalSince1970: dataPoint.timestamp)))
            partialResult[bucket, default: 0] += dataPoint.totalTokens
        }

        return fillMonthlyData(bucketValues: bucketValues, startTime: startMonth, barCount: barCount)
    }

    public static func fillHourlyOutputReasoningData(
        bucketValues: [Int64: (output: Int, reasoning: Int)],
        startTime: Date,
        barCount: Int = 24
    ) -> [OutputReasoningDataPoint] {
        let alignedStart = startOfHourUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .hour, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let pair = bucketValues[bucketMs] ?? (output: 0, reasoning: 0)

            return OutputReasoningDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .last24Hours),
                outputTokens: pair.output,
                reasoningTokens: pair.reasoning,
                bucketIndex: index,
                hasData: pair.output > 0 || pair.reasoning > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillDailyOutputReasoningData(
        bucketValues: [Int64: (output: Int, reasoning: Int)],
        startTime: Date,
        barCount: Int = 30
    ) -> [OutputReasoningDataPoint] {
        let alignedStart = startOfDayUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .day, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let pair = bucketValues[bucketMs] ?? (output: 0, reasoning: 0)

            return OutputReasoningDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .last30Days),
                outputTokens: pair.output,
                reasoningTokens: pair.reasoning,
                bucketIndex: index,
                hasData: pair.output > 0 || pair.reasoning > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillMonthlyOutputReasoningData(
        bucketValues: [Int64: (output: Int, reasoning: Int)],
        startTime: Date,
        barCount: Int = 12
    ) -> [OutputReasoningDataPoint] {
        let alignedStart = startOfMonthUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .month, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let pair = bucketValues[bucketMs] ?? (output: 0, reasoning: 0)

            return OutputReasoningDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .allTime),
                outputTokens: pair.output,
                reasoningTokens: pair.reasoning,
                bucketIndex: index,
                hasData: pair.output > 0 || pair.reasoning > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillHourlySingleMetricData(
        bucketValues: [Int64: Double],
        startTime: Date,
        barCount: Int = 24
    ) -> [SingleMetricDataPoint] {
        let alignedStart = startOfHourUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .hour, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let metricValue = bucketValues[bucketMs] ?? 0

            return SingleMetricDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .last24Hours),
                value: metricValue,
                bucketIndex: index,
                hasData: metricValue > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillDailySingleMetricData(
        bucketValues: [Int64: Double],
        startTime: Date,
        barCount: Int = 30
    ) -> [SingleMetricDataPoint] {
        let alignedStart = startOfDayUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .day, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let metricValue = bucketValues[bucketMs] ?? 0

            return SingleMetricDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .last30Days),
                value: metricValue,
                bucketIndex: index,
                hasData: metricValue > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }

    public static func fillMonthlySingleMetricData(
        bucketValues: [Int64: Double],
        startTime: Date,
        barCount: Int = 12
    ) -> [SingleMetricDataPoint] {
        let alignedStart = startOfMonthUTC(for: startTime)

        return (0..<barCount).compactMap { index in
            guard let bucketDate = localCalendar.date(byAdding: .month, value: index, to: alignedStart) else {
                return nil
            }
            let bucketMs = toBucketMs(bucketDate)
            let metricValue = bucketValues[bucketMs] ?? 0

            return SingleMetricDataPoint(
                timestamp: bucketDate.timeIntervalSince1970,
                label: formatLabel(bucketDate, timeRange: .allTime),
                value: metricValue,
                bucketIndex: index,
                hasData: metricValue > 0,
                bucketStart: bucketDate.timeIntervalSince1970
            )
        }
    }
}
