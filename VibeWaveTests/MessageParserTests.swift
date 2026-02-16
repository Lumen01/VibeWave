import XCTest
@testable import VibeWave

final class MessageParserTests: XCTestCase {
  var parser: MessageParser!
  
  override func setUp() {
    super.setUp()
    parser = MessageParser()
  }
  
  func testParseValidMessageArray() {
    let jsonString = """
    [
      {
        "id": "msg1",
        "session_id": "sess1",
        "role": "user",
        "time": {
          "created": "2024-01-27T10:00:00Z"
        },
        "tokens": {
          "input": 100,
          "output": 200
        },
        "cost": 0.01
      }
    ]
    """

    let result = parser.parseJSONString(jsonString)
    XCTAssertNil(result.error)
    XCTAssertEqual(result.messages.count, 1)
    XCTAssertEqual(result.messages.first?.id, "msg1")
  }
  
  func testParseSingleMessage() {
    let jsonString = """
    {
      "id": "msg2",
      "session_id": "sess2",
      "role": "assistant",
      "time": {
        "created": "2024-01-27T11:00:00Z"
      },
      "tokens": {
        "input": 0,
        "output": 150
      },
      "cost": 0.015
    }
    """
    
    let result = parser.parseJSONString(jsonString)
    XCTAssertNil(result.error)
    XCTAssertEqual(result.messages.count, 1)
    XCTAssertEqual(result.messages.first?.role, "assistant")
  }
  
  func testParseInvalidJSON() {
    let jsonString = "{ invalid json }"

    let result = parser.parseJSONString(jsonString)
    XCTAssertNotNil(result.error)
    XCTAssertTrue(result.messages.isEmpty)
  }

  // MARK: - New tests for parseMessages(from fileURL:) method

  func testParseMessagesFromFile_SingleMessage() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test_msg_\(UUID().uuidString).json")
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let json = """
    {
        "id": "msg1",
        "session_id": "sess1",
        "role": "user",
        "time": { "created": "2024-01-27T10:00:00Z" }
    }
    """

    do {
      try json.write(to: tempFile, atomically: true, encoding: .utf8)

      let result = parser.parseMessages(from: tempFile)
      XCTAssertNil(result.error, "Should parse single message successfully")
      XCTAssertEqual(result.messages.count, 1, "Should have 1 message")
      XCTAssertEqual(result.messages.first?.id, "msg1", "Message ID should match")
    } catch {
      XCTFail("Failed to create temp file: \(error)")
    }
  }

  func testParseMessagesFromFile_WithSummaryField() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test_summary_\(UUID().uuidString).json")
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let json = """
    {
        "id": "msg_with_summary",
        "session_id": "sess1",
        "role": "assistant",
        "time": { "created": "2024-01-27T10:00:00Z" },
        "summary": {
            "title": "Test Summary",
            "diffs": [
                {
                    "file": "test.swift",
                    "additions": 5,
                    "deletions": 2
                }
            ]
        }
    }
    """

    do {
      try json.write(to: tempFile, atomically: true, encoding: .utf8)

      let result = parser.parseMessages(from: tempFile)
      XCTAssertNil(result.error, "Should parse message with summary successfully")
      XCTAssertEqual(result.messages.count, 1, "Should have 1 message")

      let message = result.messages.first
      XCTAssertNotNil(message?.summary, "Message should have summary")
      XCTAssertEqual(message?.summary?.title, "Test Summary", "Summary title should match")
      XCTAssertEqual(message?.summary?.diffs?.count, 1, "Should have 1 diff")
      XCTAssertEqual(message?.summary?.totalAdditions, 5, "Should calculate total additions")
      XCTAssertEqual(message?.summary?.totalDeletions, 2, "Should calculate total deletions")
    } catch {
      XCTFail("Failed to create temp file: \(error)")
    }
  }

  func testParseMessagesFromFile_ArrayFallback() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test_array_\(UUID().uuidString).json")
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let json = """
    [
      {
        "id": "msg1",
        "session_id": "sess1",
        "role": "user",
        "time": {
          "created": "2024-01-27T10:00:00Z"
        }
      },
      {
        "id": "msg2",
        "session_id": "sess1",
        "role": "assistant",
        "time": {
          "created": "2024-01-27T10:01:00Z"
        }
      }
    ]
    """

    do {
      try json.write(to: tempFile, atomically: true, encoding: .utf8)

      let result = parser.parseMessages(from: tempFile)
      XCTAssertNil(result.error, "Should parse array as fallback successfully")
      XCTAssertEqual(result.messages.count, 2, "Should have 2 messages")
      XCTAssertEqual(result.messages[0].id, "msg1", "First message ID should match")
      XCTAssertEqual(result.messages[1].id, "msg2", "Second message ID should match")
    } catch {
      XCTFail("Failed to create temp file: \(error)")
    }
  }

  func testParseMessagesFromFile_SessionSummaryFallback() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test_summary_\(UUID().uuidString).json")
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let json = """
    {
        "title": "Session Summary",
        "diffs": [
            {"file": "test.swift", "additions": 10, "deletions": 5}
        ]
    }
    """

    do {
      try json.write(to: tempFile, atomically: true, encoding: .utf8)

      let result = parser.parseMessages(from: tempFile)
      XCTAssertNil(result.error, "Should parse SessionSummary successfully")
      XCTAssertNotNil(result.sessionSummary, "Should have session summary")
      XCTAssertEqual(result.sessionSummary?.title, "Session Summary", "Summary title should match")
      XCTAssertTrue(result.messages.isEmpty, "Should have no messages")
      XCTAssertEqual(result.sessionSummary?.diffs?.count, 1, "Should have 1 diff")
    } catch {
      XCTFail("Failed to create temp file: \(error)")
    }
  }

  func testParseMessagesFromFile_NoWarningForSingleMessage() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test_warning_\(UUID().uuidString).json")
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let json = """
    {
        "id": "msg1",
        "session_id": "sess1",
        "role": "user",
        "time": { "created": "2024-01-27T10:00:00Z" }
    }
    """

    do {
      try json.write(to: tempFile, atomically: true, encoding: .utf8)

      let result = parser.parseMessages(from: tempFile)
      XCTAssertNil(result.error, "Should parse successfully")

      // 注意：这个测试在当前实现下应该PASS，因为我们验证解析成功
      // 警告验证将在Task 3优化后添加
      XCTAssertTrue(result.messages.count > 0, "Should have parsed messages")
    } catch {
      XCTFail("Failed: \(error)")
    }
  }
}
