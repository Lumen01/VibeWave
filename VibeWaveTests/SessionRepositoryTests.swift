import XCTest
import GRDB
@testable import VibeWave

final class SessionRepositoryTests: XCTestCase {
  var dbPool: DatabasePool!
  var sessionRepo: SessionRepository!
  var messageRepo: MessageRepository!
  private var tempDBPath: String?

  override func setUp() {
    super.setUp()
    // DatabasePool requires WAL mode, which is not supported by :memory:
    let tempDBFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_session_repository-\(UUID().uuidString).db")
    tempDBPath = tempDBFile.path
    dbPool = try! DatabasePool(path: tempDBFile.path)
    sessionRepo = SessionRepository(dbPool: dbPool)
    messageRepo = MessageRepository(dbPool: dbPool)
    try! messageRepo.createSchemaIfNeeded()
    try! dbPool.write { db in
      try db.execute(sql: """
        CREATE TABLE IF NOT EXISTS sessions (
          session_id TEXT PRIMARY KEY,
          first_message_at REAL,
          last_message_at REAL,
          user_msg_count INTEGER,
          agent_msg_count INTEGER,
          total_input_tokens INTEGER,
          total_output_tokens INTEGER,
          total_reasoning_tokens INTEGER,
          total_cache_read INTEGER,
          total_cache_write INTEGER,
          total_cost REAL,
          is_orphan INTEGER,
          total_additions INTEGER,
          total_deletions INTEGER,
          total_file_count INTEGER,
          total_edits INTEGER,
          project_name TEXT,
          finish_reason TEXT
        )
        """)
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

  func testCreateSessionsFromMessages() throws {
    let t1 = MessageTime(created: "2020-01-01T10:00:00Z", completed: nil)
    let t2 = MessageTime(created: "2020-01-01T11:00:00Z", completed: nil)
    let m1 = Message(id: "m1", sessionID: "sess1", role: "user", time: t1, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 100, output: 200, reasoning: 0), cost: 0.01)
    let m2 = Message(id: "m2", sessionID: "sess1", role: "assistant", time: t2, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 0, output: 150, reasoning: 50), cost: 0.015)
    
    try messageRepo.insert(message: m1)
    try messageRepo.insert(message: m2)
    try sessionRepo.createSessionsFromMessages()
    
    let session = sessionRepo.fetch(by: "sess1")
    XCTAssertNotNil(session)
    // After schema change: m1 is user (role="user"), m2 is agent (role="assistant")
    XCTAssertEqual(session?.userMsgCount, 1, "userMsgCount should be 1 (m1 is user)")
    XCTAssertEqual(session?.agentMsgCount, 1, "agentMsgCount should be 1 (m2 is assistant)")
  }

  func testFetchAllSessions() {
    let t = MessageTime(created: "2020-01-01T10:00:00Z", completed: nil)
    let m = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    try! messageRepo.insert(message: m)
    try! sessionRepo.createSessionsFromMessages()
    
    let sessions = sessionRepo.fetchAll()
    XCTAssertEqual(sessions.count, 1)
  }

  func testSessionDepth() {
    // Test shallow session (≤3 messages)
    let t = MessageTime(created: "2020-01-01T10:00:00Z", completed: nil)
    let m1 = Message(id: "m1", sessionID: "sess1", role: "user", time: t, parentID: nil, providerID: nil, modelID: nil, agent: nil, mode: nil, variant: nil, cwd: nil, root: nil, tokens: Tokens(input: 1, output: 1, reasoning: 1), cost: 0.0)
    try! messageRepo.insert(message: m1)
    try! sessionRepo.createSessionsFromMessages()
    
    let depth = sessionRepo.getSessionDepth(sessionId: "sess1")
    XCTAssertEqual(depth, "shallow")
  }

  func testCreateSessionsFromMessages_extractsProjectNameFromTrailingSlashRoot() throws {
    let t = MessageTime(created: "2020-01-01T10:00:00Z", completed: nil)
    let message = Message(
      id: "m-trailing-slash",
      sessionID: "sess-trailing",
      role: "user",
      time: t,
      parentID: nil,
      providerID: nil,
      modelID: nil,
      agent: nil,
      mode: nil,
      variant: nil,
      cwd: "/Users/alice/MyApp/",
      root: "/Users/alice/MyApp/",
      tokens: Tokens(input: 1, output: 1, reasoning: 0),
      cost: 0.0
    )

    try messageRepo.insert(message: message)
    try sessionRepo.createSessionsFromMessages()

    let session = sessionRepo.fetch(by: "sess-trailing")
    XCTAssertEqual(session?.projectName, "MyApp")
  }
}
