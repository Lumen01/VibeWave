import XCTest
import GRDB
@testable import VibeWave

final class MessageRepositoryTests: XCTestCase {
  var dbPool: DatabasePool!
  var repo: MessageRepository!
  private var tempDBPath: String?

  override func setUp() {
    super.setUp()
    // DatabasePool requires WAL mode, which is not supported by :memory:
    let tempDBFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_message_repository-\(UUID().uuidString).db")
    tempDBPath = tempDBFile.path
    dbPool = try! DatabasePool(path: tempDBFile.path)
    repo = MessageRepository(dbPool: dbPool)
    try? repo.createSchemaIfNeeded()
  }

  override func tearDown() {
    repo = nil
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

func testInsertAndIdempotency() {
    // Build a Message matching the OpenCode schema
    let t = MessageTime(created: "2020-01-01T00:00:00Z", completed: nil)
    let tokens = Tokens(input: 1, output: 2, reasoning: 3)
    let m = Message(
      id: "m1",
      sessionID: "sess1",
      role: "user",
      time: t,
      parentID: nil,
      providerID: nil,
      modelID: nil,
      agent: nil,
      mode: nil,
      variant: nil,
      cwd: nil,
      root: nil,
      tokens: tokens,
      cost: 0.0
    )
    XCTAssertNoThrow(try repo.insert(message: m))
    // Insert duplicate should be ignored
    XCTAssertNoThrow(try repo.insert(message: m))
    // Verify only one row exists
    let count = try! dbPool.read { db in
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages") ?? 0
    }
    XCTAssertEqual(count, 1)
  }

  func testInsertBatchMessages() throws {
    let t1 = MessageTime(created: "2020-01-01T00:00:00Z", completed: nil)
    let t2 = MessageTime(created: "2020-01-01T00:00:01Z", completed: nil)
    let tokens1 = Tokens(input: 1, output: 2, reasoning: 3)
    let tokens2 = Tokens(input: 4, output: 5, reasoning: 6)
    let m1 = Message(
      id: "batch-1",
      sessionID: "sess-batch",
      role: "user",
      time: t1,
      parentID: nil,
      providerID: nil,
      modelID: nil,
      agent: nil,
      mode: nil,
      variant: nil,
      cwd: nil,
      root: nil,
      tokens: tokens1,
      cost: 0.0
    )
    let m2 = Message(
      id: "batch-2",
      sessionID: "sess-batch",
      role: "assistant",
      time: t2,
      parentID: nil,
      providerID: nil,
      modelID: nil,
      agent: nil,
      mode: nil,
      variant: nil,
      cwd: nil,
      root: nil,
      tokens: tokens2,
      cost: 0.0
    )

    XCTAssertNoThrow(try repo.insert(messages: [m1, m2]))

    let count = try dbPool.read { db in
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages") ?? 0
    }
    XCTAssertEqual(count, 2)

    XCTAssertNoThrow(try repo.insert(messages: [m1]))

    let countAfter = try dbPool.read { db in
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages") ?? 0
    }
    XCTAssertEqual(countAfter, 2)
  }

func testFetchByID() {
    let t = MessageTime(created: "2020-01-01T00:00:01Z", completed: nil)
    let tokens = Tokens(input: 1, output: 1, reasoning: 1)
    let m = Message(
      id: "m2",
      sessionID: "sess2",
      role: "user",
      time: t,
      parentID: nil,
      providerID: nil,
      modelID: nil,
      agent: nil,
      mode: nil,
      variant: nil,
      cwd: nil,
      root: nil,
      tokens: tokens,
      cost: 0.0
    )
    try! repo.insert(message: m)
    if let rec = repo.fetch(by: m.id) {
      XCTAssertEqual(rec.id, m.id)
    } else {
      XCTFail("Expected a record for id \(m.id)")
    }
  }

  func testFetchBySession() {
    let t1 = MessageTime(created: "2020-01-01T00:00:00Z", completed: nil)
    let t2 = MessageTime(created: "2020-01-01T00:00:01Z", completed: nil)
    let t3 = MessageTime(created: "2020-01-01T00:00:02Z", completed: nil)
    let m1 = Message(id: "a1", sessionID: "sess", role: "user", time: t1, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    let m2 = Message(id: "a2", sessionID: "sess", role: "user", time: t2, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    let m3 = Message(id: "b1", sessionID: "other", role: "user", time: t3, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    try! repo.insert(message: m1)
    try! repo.insert(message: m2)
    try! repo.insert(message: m3)
    let results = repo.fetchBy(sessionId: "sess")
    XCTAssertEqual(results.map { $0.id }.sorted(), ["a1", "a2"].sorted())
  }

  func testFetchAllWithTimeRange() throws {
    let base = Date(timeIntervalSince1970: 1_000_000_000)
    let dateFormatter = ISO8601DateFormatter()
    let m1 = Message(id: "t1", sessionID: "s", role: "user", time: MessageTime(created: dateFormatter.string(from: base.addingTimeInterval(-60)), completed: nil), parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    let m2 = Message(id: "t2", sessionID: "s", role: "user", time: MessageTime(created: dateFormatter.string(from: base), completed: nil), parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    let m3 = Message(id: "t3", sessionID: "s", role: "user", time: MessageTime(created: dateFormatter.string(from: base.addingTimeInterval(120)), completed: nil), parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    try repo.insert(message: m1)
    try repo.insert(message: m2)
    try repo.insert(message: m3)

    let start = base.addingTimeInterval(-30)
    let end = base.addingTimeInterval(150)
    let recs = repo.fetchAll(startTimestamp: start, endTimestamp: end)
    XCTAssertEqual(recs.map { $0.id }.sorted(), ["t2", "t3"].sorted())
  }
}
