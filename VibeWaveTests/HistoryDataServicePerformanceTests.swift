import XCTest
import GRDB
@testable import VibeWave

/// Performance benchmarks for HistoryDataService queries
final class HistoryDataServicePerformanceTests: XCTestCase {
    var service: HistoryDataService!
    var dbPool: DatabasePool!
    
    override func setUp() {
        super.setUp()
        dbPool = try! DatabasePool(path: ":memory:")
        service = HistoryDataService(repository: StatisticsRepository(dbPool: dbPool))
        
        // Insert test data into hourly_stats for benchmark
        try! setupTestDatabase()
    }
    
    override func tearDown() {
        service = nil
        dbPool = nil
        super.tearDown()
    }
    
    // MARK: - Query Performance Benchmarks
    
    func testGetHourlyInputTokensFromAggregatedTable_Performance() {
        // Given: Test data populated in hourly_stats
        // When: Getting 24-hour Input Tokens history
        measure {
            _ = service.getHourlyInputTokensFromAggregatedTable()
        }
        
        // Then: Should process 24 data points efficiently
    }
    
    func testTimeSeriesFillerFillHourlyData_Performance() {
        // Given: Various data scenarios
        let emptyData: [InputTokensDataPoint] = []
        let partialData: [InputTokensDataPoint] = [
            InputTokensDataPoint(timestamp: Date().timeIntervalSince1970, label: "12", totalTokens: 1000, segments: [])
        ]
        
        // When: Filling hourly data
        measure {
            _ = TimeSeriesFiller.fillHourlyData(existingData: emptyData, endTime: Date())
        }
        
        measure {
            _ = TimeSeriesFiller.fillHourlyData(existingData: partialData, endTime: Date())
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupTestDatabase() throws {
        try dbPool.write { db in
            try DatabaseRepository.createAggregationTables(on: db)

            // Insert test hourly_stats records
            var timeBucketMs = Int64((Date().addingTimeInterval(-23 * 3600)).timeIntervalSince1970 * 1000)
            
            for _ in 0..<24 {
                try db.execute(sql: """
                    INSERT INTO hourly_stats 
                    (time_bucket_ms, project_id, model_id, input_tokens, output_tokens, reasoning_tokens)
                    VALUES (?, 'project-a', 'model-1', 5000, 3000, 0)
                """, arguments: [timeBucketMs])
                timeBucketMs += 3600 * 1000
            }
        }
    }
}
