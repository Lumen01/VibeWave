import XCTest
@testable import VibeWave

final class TimeSeriesFillerTests: XCTestCase {
    private func utcDate(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: components)!
    }

    private func toMs(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    func testFillHourlyDataProducesFixed24Buckets() {
        let start = utcDate(year: 2026, month: 2, day: 12)
        let bucketDate = utcDate(year: 2026, month: 2, day: 12, hour: 5)

        let result = TimeSeriesFiller.fillHourlyData(
            bucketValues: [toMs(bucketDate): 123],
            startTime: start,
            barCount: 24
        )

        XCTAssertEqual(result.count, 24)
        XCTAssertEqual(result[5].totalTokens, 123)
        XCTAssertTrue(result[5].hasData)
        XCTAssertEqual(result[5].bucketIndex, 5)
        XCTAssertEqual(result[0].totalTokens, 0)
        XCTAssertFalse(result[0].hasData)
        XCTAssertEqual(result[23].bucketIndex, 23)
    }

    func testFillDailyDataProducesFixed30Buckets() {
        let start = utcDate(year: 2026, month: 1, day: 14)
        let bucketDate = utcDate(year: 2026, month: 2, day: 1)

        let result = TimeSeriesFiller.fillDailyData(
            bucketValues: [toMs(bucketDate): 456],
            startTime: start,
            barCount: 30
        )

        XCTAssertEqual(result.count, 30)
        XCTAssertEqual(result[18].totalTokens, 456)
        XCTAssertTrue(result[18].hasData)
        XCTAssertEqual(result[29].bucketIndex, 29)
    }

    func testFillMonthlyDataProducesFixed12BucketsAcrossYear() {
        let start = utcDate(year: 2025, month: 3, day: 1)
        let bucketDate = utcDate(year: 2026, month: 1, day: 1)

        let result = TimeSeriesFiller.fillMonthlyData(
            bucketValues: [toMs(bucketDate): 789],
            startTime: start,
            barCount: 12
        )

        XCTAssertEqual(result.count, 12)
        XCTAssertEqual(result[10].totalTokens, 789)
        XCTAssertTrue(result[10].hasData)
        XCTAssertEqual(result[11].bucketIndex, 11)
    }
}
