import XCTest
@testable import VibeWave

final class HistoryTrendComputationTests: XCTestCase {
    func testSignedDeltaSeries_FirstPointIsZeroAndKeepsNegativeChanges() {
        let base = Date(timeIntervalSince1970: 1_707_900_000)
        let points = [
            SingleMetricDataPoint(
                timestamp: base.timeIntervalSince1970,
                label: "A",
                value: 100,
                bucketIndex: 0,
                hasData: true,
                bucketStart: base.timeIntervalSince1970
            ),
            SingleMetricDataPoint(
                timestamp: base.addingTimeInterval(3600).timeIntervalSince1970,
                label: "B",
                value: 130,
                bucketIndex: 1,
                hasData: true,
                bucketStart: base.addingTimeInterval(3600).timeIntervalSince1970
            ),
            SingleMetricDataPoint(
                timestamp: base.addingTimeInterval(7200).timeIntervalSince1970,
                label: "C",
                value: 90,
                bucketIndex: 2,
                hasData: true,
                bucketStart: base.addingTimeInterval(7200).timeIntervalSince1970
            )
        ]

        let delta = TrendDeltaChartMath.signedDeltaSeries(from: points)

        XCTAssertEqual(delta.count, 3)
        XCTAssertEqual(delta[0].value, 0, accuracy: 0.0001)
        XCTAssertEqual(delta[1].value, 30, accuracy: 0.0001)
        XCTAssertEqual(delta[2].value, -40, accuracy: 0.0001)
    }

    func testCumulativeSeries_AccumulatesUsageOverTime() {
        let points = [
            SingleMetricDataPoint(timestamp: 1, label: "A", value: 1_000_000, bucketIndex: 0, bucketStart: 1),
            SingleMetricDataPoint(timestamp: 2, label: "B", value: 2_000_000, bucketIndex: 1, bucketStart: 2),
            SingleMetricDataPoint(timestamp: 3, label: "C", value: 500_000, bucketIndex: 2, bucketStart: 3)
        ]

        let cumulative = TrendDeltaChartMath.cumulativeSeries(from: points)

        XCTAssertEqual(cumulative.count, 3)
        XCTAssertEqual(cumulative[0].value, 1_000_000, accuracy: 0.0001)
        XCTAssertEqual(cumulative[1].value, 3_000_000, accuracy: 0.0001)
        XCTAssertEqual(cumulative[2].value, 3_500_000, accuracy: 0.0001)
    }

    func testNaturalDaySpan_IsInclusiveByCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let start = calendar.date(from: DateComponents(year: 2026, month: 2, day: 14, hour: 23, minute: 50))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 0, minute: 10))!

        let daySpan = TrendDeltaChartMath.naturalDaySpan(start: start, end: end, calendar: calendar)
        XCTAssertEqual(daySpan, 2)
    }

    func testAveragePerDay_UsesNaturalDaySpanFromBucketBounds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let start = calendar.date(from: DateComponents(year: 2026, month: 2, day: 14, hour: 12))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 3))!

        let avg = TrendDeltaChartMath.averagePerDay(
            total: 48,
            startBucketStart: start.timeIntervalSince1970,
            endBucketStart: end.timeIntervalSince1970,
            calendar: calendar
        )
        XCTAssertEqual(avg, 24, accuracy: 0.0001)
    }

    func testYDomain_IncludesNegativeWhenDeltaHasNegativeValues() {
        let history = [
            SingleMetricDataPoint(timestamp: 1, label: "A", value: 100, bucketIndex: 0, bucketStart: 1),
            SingleMetricDataPoint(timestamp: 2, label: "B", value: 120, bucketIndex: 1, bucketStart: 2)
        ]
        let delta = [
            SingleMetricDataPoint(timestamp: 1, label: "A", value: 0, bucketIndex: 0, bucketStart: 1),
            SingleMetricDataPoint(timestamp: 2, label: "B", value: -30, bucketIndex: 1, bucketStart: 2)
        ]

        let domain = TrendDeltaChartMath.yDomain(history: history, delta: delta)

        XCTAssertLessThanOrEqual(domain.lowerBound, -30)
        XCTAssertGreaterThanOrEqual(domain.upperBound, 120)
        XCTAssertTrue(domain.contains(0))
    }

    func testSignedFormatters_TokensAndHours() {
        XCTAssertEqual(TrendDeltaValueFormatter.formatSignedTokens(1_200), "+1.2K")
        XCTAssertEqual(TrendDeltaValueFormatter.formatSignedTokens(-850), "-850")
        XCTAssertEqual(TrendDeltaValueFormatter.formatSignedHours(1.5), "+1.5h")
        XCTAssertEqual(TrendDeltaValueFormatter.formatSignedHours(-0.4), "-0.4h")
        XCTAssertEqual(TrendDeltaValueFormatter.formatAxisTokens(1_200), "1.2K")
        XCTAssertEqual(TrendDeltaValueFormatter.formatAxisTokens(-850), "-850")
        XCTAssertEqual(TrendDeltaValueFormatter.formatAxisHours(1.5), "1.5h")
        XCTAssertEqual(TrendDeltaValueFormatter.formatAxisHours(-0.4), "-0.4h")
    }
}
