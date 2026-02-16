import XCTest
import GRDB
@testable import VibeWave

final class HistoryDataServiceTests: XCTestCase {
    var dbPool: DatabasePool!
    var repository: StatisticsRepository!
    var service: HistoryDataService!
    
    override func setUp() {
        super.setUp()
        dbPool = try! DatabasePool(path: ":memory:")
        repository = StatisticsRepository(dbPool: dbPool)
        service = HistoryDataService(repository: repository)
        try! dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)
        }
    }
    
    override func tearDown() {
        dbPool = nil
        repository = nil
        service = nil
        super.tearDown()
    }
    
    func testGetHourlyInputTokensFromAggregatedTable_Returns24DataPoints() {
        // Act
        let result = service.getHourlyInputTokensFromAggregatedTable()
        
        // Assert
        XCTAssertEqual(result.count, 24, "Should return exactly 24 hourly data points")
    }
    
    func testGetDailyInputTokensFromAggregatedTable_Returns30DataPoints() {
        let result = service.getDailyInputTokensFromAggregatedTable()
        XCTAssertEqual(result.count, 30, "Should return exactly 30 daily data points")
    }

    func testGetAllTimeInputTokensFromAggregatedTable_Returns12DataPoints() {
        let result = service.getAllTimeInputTokensFromAggregatedTable()
        XCTAssertEqual(result.count, 12, "Should return exactly 12 monthly data points")
        XCTAssertTrue(result.allSatisfy { $0.totalTokens == 0 }, "Empty database should produce zero-filled placeholders")
    }

    func testGetHourlyOutputReasoningFromAggregatedTable_Returns24DataPoints() {
        let result = service.getHourlyOutputReasoningFromAggregatedTable()
        XCTAssertEqual(result.count, 24, "Should return exactly 24 hourly data points")
        XCTAssertTrue(result.allSatisfy { $0.outputTokens == 0 && $0.reasoningTokens == 0 })
    }

    func testGetDailyOutputReasoningFromAggregatedTable_Returns30DataPoints() {
        let result = service.getDailyOutputReasoningFromAggregatedTable()
        XCTAssertEqual(result.count, 30, "Should return exactly 30 daily data points")
        XCTAssertTrue(result.allSatisfy { $0.outputTokens == 0 && $0.reasoningTokens == 0 })
    }

    func testGetAllTimeOutputReasoningFromAggregatedTable_Returns12DataPoints() {
        let result = service.getAllTimeOutputReasoningFromAggregatedTable()
        XCTAssertEqual(result.count, 12, "Should return exactly 12 monthly data points")
        XCTAssertTrue(result.allSatisfy { $0.outputTokens == 0 && $0.reasoningTokens == 0 })
    }

    func testGetHourlyCostFromAggregatedTable_Returns24DataPoints() {
        let result = service.getHourlyCostFromAggregatedTable()
        XCTAssertEqual(result.count, 24, "Should return exactly 24 hourly data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetDailyCostFromAggregatedTable_Returns30DataPoints() {
        let result = service.getDailyCostFromAggregatedTable()
        XCTAssertEqual(result.count, 30, "Should return exactly 30 daily data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetAllTimeCostFromAggregatedTable_Returns12DataPoints() {
        let result = service.getAllTimeCostFromAggregatedTable()
        XCTAssertEqual(result.count, 12, "Should return exactly 12 monthly data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetHourlySessionsFromAggregatedTable_Returns24DataPoints() {
        let result = service.getHourlySessionsFromAggregatedTable()
        XCTAssertEqual(result.count, 24, "Should return exactly 24 hourly data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetDailySessionsFromAggregatedTable_Returns30DataPoints() {
        let result = service.getDailySessionsFromAggregatedTable()
        XCTAssertEqual(result.count, 30, "Should return exactly 30 daily data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetAllTimeSessionsFromAggregatedTable_Returns12DataPoints() {
        let result = service.getAllTimeSessionsFromAggregatedTable()
        XCTAssertEqual(result.count, 12, "Should return exactly 12 monthly data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetHourlyMessageDurationHoursFromAggregatedTable_Returns24DataPoints() {
        let result = service.getHourlyMessageDurationHoursFromAggregatedTable()
        XCTAssertEqual(result.count, 24, "Should return exactly 24 hourly data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetDailyMessageDurationHoursFromAggregatedTable_Returns30DataPoints() {
        let result = service.getDailyMessageDurationHoursFromAggregatedTable()
        XCTAssertEqual(result.count, 30, "Should return exactly 30 daily data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetAllTimeMessageDurationHoursFromAggregatedTable_Returns12DataPoints() {
        let result = service.getAllTimeMessageDurationHoursFromAggregatedTable()
        XCTAssertEqual(result.count, 12, "Should return exactly 12 monthly data points")
        XCTAssertTrue(result.allSatisfy { $0.value == 0 })
    }

    func testGetDailyMessageDurationHoursFromAggregatedTable_ConvertsMillisecondsToHours() throws {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: Date())
        let todayMs = Int64(todayStart.timeIntervalSince1970 * 1000)

        try dbPool.write { db in
            try db.execute(
                sql: """
                INSERT INTO daily_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id, duration_ms
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [todayMs, "proj-duration", "openai", "gpt-4", "assistant", "unknown", "opencode", 7_200_000]
            )
        }

        let result = service.getDailyMessageDurationHoursFromAggregatedTable()

        XCTAssertEqual(result.count, 30)
        let target = result.first(where: { Int64($0.bucketStart * 1000) == todayMs })
        XCTAssertNotNil(target, "Expected daily bucket for today")
        XCTAssertEqual(target?.value ?? -1, 2.0, accuracy: 0.0001, "7_200_000ms should equal 2.0 hours")
    }

    func testHourlySeries_LastBucketAlignsWithCurrentHourAcrossAllCharts() {
        let expectedCurrentHourStart = currentHourStart()

        let inputLast = service.getHourlyInputTokensFromAggregatedTable().last?.bucketStart
        let outputLast = service.getHourlyOutputReasoningFromAggregatedTable().last?.bucketStart
        let costLast = service.getHourlyCostFromAggregatedTable().last?.bucketStart
        let sessionsLast = service.getHourlySessionsFromAggregatedTable().last?.bucketStart
        let messagesLast = service.getHourlyMessagesFromAggregatedTable().last?.bucketStart

        let lastBucketStarts: [TimeInterval?] = [inputLast, outputLast, costLast, sessionsLast, messagesLast]
        for bucketStart in lastBucketStarts {
            guard let bucketStart else {
                XCTFail("Hourly series should contain a last bucket")
                continue
            }
            XCTAssertEqual(
                bucketStart,
                expectedCurrentHourStart.timeIntervalSince1970,
                accuracy: 0.001,
                "Latest 24-hour bucket should be the current hour"
            )
        }
    }

    private func currentHourStart(reference: Date = Date()) -> Date {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: reference)
        return calendar.date(from: components) ?? reference
    }
}
