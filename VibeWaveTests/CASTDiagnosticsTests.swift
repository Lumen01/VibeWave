import XCTest
import GRDB

final class CASTDiagnosticsTests: XCTestCase {
    var dbPool: DatabasePool!

    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        let tempDBPath = tempDir + "cast-test-\(UUID().uuidString).db"
        dbPool = try! DatabasePool(path: tempDBPath)
    }

    override func tearDown() {
        try? dbPool.close()
        super.tearDown()
    }

    func testCASTBehavior() {
        try? dbPool.write { db in
            try db.execute(sql: "CREATE TABLE test (value TEXT)")
            try db.execute(sql: "INSERT INTO test VALUES ('150')")
            try db.execute(sql: "INSERT INTO test VALUES ('75')")
            
            // Test 1: Direct SUM on TEXT
            print("[CAST] Test 1: SUM on TEXT")
            let row1 = try Row.fetchOne(db, sql: "SELECT SUM(value) as sum FROM test")
            print("[CAST] SUM(text) as Int64: \(row1?["sum"] as? Int64 ?? -999)")
            print("[CAST] SUM(text) as Double: \(row1?["sum"] as? Double ?? -999)")
            print("[CAST] SUM(text) raw: \(String(describing: row1?["sum"]))")
            
            // Test 2: SUM with CAST
            print("[CAST] Test 2: SUM with CAST")
            let row2 = try Row.fetchOne(db, sql: "SELECT SUM(CAST(value AS INTEGER)) as sum FROM test")
            print("[CAST] SUM(CAST) as Int64: \(row2?["sum"] as? Int64 ?? -999)")
            print("[CAST] SUM(CAST) as Double: \(row2?["sum"] as? Double ?? -999)")
            
            // Test 3: Direct value retrieval
            print("[CAST] Test 3: Direct value")
            let row3 = try Row.fetchOne(db, sql: "SELECT value FROM test LIMIT 1")
            print("[CAST] Direct value: \(String(describing: row3?["value"]))")
            
            // Test 4: Type check
            print("[CAST] Test 4: Type check")
            let rows = try Row.fetchAll(db, sql: "SELECT typeof(value) as t, value FROM test")
            for row in rows {
                print("[CAST] Type: \(row["t"] as? String ?? "nil"), Value: \(String(describing: row["value"]))")
            }
        }
    }
}
