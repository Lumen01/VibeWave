import Foundation

public enum TrendDeltaChartMath {
    public static func cumulativeSeries(from points: [SingleMetricDataPoint]) -> [SingleMetricDataPoint] {
        guard !points.isEmpty else { return [] }

        var runningTotal = 0.0
        return points.map { point in
            runningTotal += point.value
            return SingleMetricDataPoint(
                timestamp: point.timestamp,
                label: point.label,
                value: runningTotal,
                bucketIndex: point.bucketIndex,
                hasData: point.hasData,
                bucketStart: point.bucketStart
            )
        }
    }

    public static func signedDeltaSeries(from points: [SingleMetricDataPoint]) -> [SingleMetricDataPoint] {
        guard !points.isEmpty else { return [] }

        return points.enumerated().map { index, point in
            let value: Double
            if index == 0 {
                value = 0
            } else {
                value = point.value - points[index - 1].value
            }

            return SingleMetricDataPoint(
                timestamp: point.timestamp,
                label: point.label,
                value: value,
                bucketIndex: point.bucketIndex,
                hasData: point.hasData,
                bucketStart: point.bucketStart
            )
        }
    }

    public static func naturalDaySpan(start: Date, end: Date, calendar: Calendar = Calendar.autoupdatingCurrent) -> Int {
        let normalizedStart = calendar.startOfDay(for: min(start, end))
        let normalizedEnd = calendar.startOfDay(for: max(start, end))
        let deltaDays = calendar.dateComponents([.day], from: normalizedStart, to: normalizedEnd).day ?? 0
        return max(1, deltaDays + 1)
    }

    public static func averagePerDay(
        total: Double,
        startBucketStart: TimeInterval?,
        endBucketStart: TimeInterval?,
        calendar: Calendar = Calendar.autoupdatingCurrent
    ) -> Double {
        guard let startBucketStart, let endBucketStart else {
            return total
        }

        let daySpan = naturalDaySpan(
            start: Date(timeIntervalSince1970: startBucketStart),
            end: Date(timeIntervalSince1970: endBucketStart),
            calendar: calendar
        )
        return daySpan > 0 ? total / Double(daySpan) : total
    }

    public static func yDomain(history: [SingleMetricDataPoint], delta: [SingleMetricDataPoint]) -> ClosedRange<Double> {
        let allValues = (history.map(\.value) + delta.map(\.value))
        guard let minValue = allValues.min(), let maxValue = allValues.max() else {
            return 0...1
        }

        if minValue >= 0 {
            if maxValue <= 0 {
                return 0...1
            }
            return 0...(maxValue * 1.1)
        }

        let absoluteBound = max(abs(minValue), abs(maxValue))
        if absoluteBound == 0 {
            return -1...1
        }
        let padded = absoluteBound * 1.1
        return (-padded)...padded
    }
}
