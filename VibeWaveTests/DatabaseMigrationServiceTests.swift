import XCTest
import GRDB
@testable import VibeWave

final class DatabaseMigrationServiceTests: XCTestCase {
  var dbPool: DatabasePool!
  var messageRepo: MessageRepository!
  var sessionRepo: SessionRepository!
  private var tempDBPath: String?

  override func setUp() {
    super.setUp()
    let tempDBFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_db_migration_service-\(UUID().uuidString).db")
    tempDBPath = tempDBFile.path
    dbPool = try! DatabasePool(path: tempDBFile.path)
    messageRepo = MessageRepository(dbPool: dbPool)
    sessionRepo = SessionRepository(dbPool: dbPool)
    try! dbPool.write { db in
      try DatabaseRepository.bootstrapSchema(on: db)
    }
  }

  override func tearDown() {
    sessionRepo = nil
    messageRepo = nil
    try? dbPool.close()
    dbPool = nil
    if let path = tempDBPath {
      try? FileManager.default.removeItem(atPath: path)
      try? FileManager.default.removeItem(atPath: path + "-wal")
      try? FileManager.default.removeItem(atPath: path + "-shm")
    }
    tempDBPath = nil
    super.tearDown()
  }

  func testPerformMigrations_rebuildsMonthlyStatsAfterTruncation() throws {
    let time = MessageTime(created: "2026-01-15T08:00:00Z", completed: "2026-01-15T08:01:00Z")
    let message = Message(
      id: "m-migration-monthly",
      sessionID: "sess-migration-monthly",
      role: "assistant",
      time: time,
      parentID: nil,
      providerID: "openai",
      modelID: "gpt-5",
      agent: "assistant",
      mode: nil,
      variant: nil,
      cwd: "/Users/alice/MyApp",
      root: "/Users/alice/MyApp",
      tokens: Tokens(input: 10, output: 20, reasoning: 5),
      cost: 0.02
    )
    try messageRepo.insert(message: message)
    try sessionRepo.createSessionsFromMessages()

    try dbPool.write { db in
      try db.execute(sql: """
        INSERT INTO monthly_stats (
          time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
          session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
          cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
          last_created_at_ms
        ) VALUES (
          0, 'stale', 'stale', 'stale', 'stale', 'stale', 'opencode',
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
      """)
    }

    let service = DatabaseMigrationService(dbPool: dbPool)
    try service.performMigrations()

    try dbPool.read { db in
      let monthlyCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM monthly_stats") ?? 0
      XCTAssertGreaterThan(monthlyCount, 0)
    }
  }
}
