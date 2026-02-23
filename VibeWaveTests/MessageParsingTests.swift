import XCTest
@testable import VibeWave

final class MessageParsingTests: XCTestCase {
    func testValidFullMessageParsing() throws {
        let json = """
        {
            "id": "msg_001",
            "session_id": "sess_123",
            "role": "user",
            "time": { "created": "2026-01-27T12:00:00Z", "completed": "2026-01-27T12:01:00Z" },
            "parent_id": "parent_1",
            "provider_id": "provA",
            "model_id": "modelX",
            "agent": "agent007",
            "mode": "auto",
            "variant": "v1",
            "cwd": "/workspace",
            "root": "/",
            "tokens": { "input": 10, "output": 20, "reasoning": 5, "cache": { "read": 2, "write": 1 } },
            "cost": 0.123
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        do {
            let message = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(message.id, "msg_001")
            XCTAssertEqual(message.sessionID, "sess_123")
            XCTAssertEqual(message.role, "user")
            XCTAssertNotNil(message.time)
            XCTAssertEqual(message.time?.created, "2026-01-27T12:00:00Z")
            XCTAssertEqual(message.time?.completed, "2026-01-27T12:01:00Z")
            XCTAssertEqual(message.tokens?.input, 10)
            XCTAssertEqual(message.cost, 0.123)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }

    func testOptionalTimeCompletedMissing() throws {
        let json = """
        {
            "id": "msg_002",
            "session_id": "sess_124",
            "role": "system",
            "time": { "created": "2026-01-27T12:02:00Z" }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        do {
            let message = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(message.id, "msg_002")
            XCTAssertNil(message.time?.completed)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }

    func testMalformedJSONThrowsError() {
        let json = """
        { "id": "msg_003", "session_id": "sess_125" "role": "user" }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Message.self, from: data))
    }

    func testArrayOfMessagesParsing() throws {
        let json = """
        [
            { "id": "msg_004", "session_id": "sess_126", "role": "user", "time": { "created": "2026-01-27T12:00:00Z" } },
            { "id": "msg_005", "session_id": "sess_127", "role": "assistant", "time": { "created": "2026-01-27T12:01:00Z" } }
        ]
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        do {
            let messages = try decoder.decode([Message].self, from: data)
            XCTAssertEqual(messages.count, 2)
            XCTAssertEqual(messages[0].id, "msg_004")
            XCTAssertEqual(messages[1].role, "assistant")
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }
    
    func testMessageWithSummaryField() throws {
        let json = """
        {
            "id": "msg_with_summary",
            "session_id": "sess_128",
            "role": "assistant",
            "time": { "created": "2026-01-27T12:00:00Z" },
            "summary": {
                "title": "功能实现",
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
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        do {
            let message = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(message.id, "msg_with_summary")
            XCTAssertNotNil(message.summary)
            XCTAssertEqual(message.summary?.title, "功能实现")
            XCTAssertEqual(message.summary?.diffs?.count, 1)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }

    func testCamelCaseProviderAndModelDecodeWhenSessionIDAndSession_idBothPresent() throws {
        let json = """
        {
            "id": "msg_camel_provider",
            "sessionID": "sess_200",
            "session_id": "sess_200",
            "role": "assistant",
            "time": { "created": 1769912533370, "completed": 1769912540633 },
            "providerID": "nvidia",
            "modelID": "z-ai/glm4.7"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(message.providerID, "nvidia")
        XCTAssertEqual(message.modelID, "z-ai/glm4.7")
    }

    func testMessageWithTopLevelCwdAndRoot_SnakeCase() throws {
        // Test that Message can parse top-level cwd and root fields (snake_case format from OpenCode)
        let json = """
        {
            "id": "msg_cwd_root_snake",
            "session_id": "sess_cwd_test",
            "role": "assistant",
            "time": { "created": "2026-01-27T12:00:00Z" },
            "cwd": "/Users/testuser/project",
            "root": "/Users/testuser"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: data)
        
        XCTAssertEqual(message.cwd, "/Users/testuser/project")
        XCTAssertEqual(message.root, "/Users/testuser")
    }
    
    func testMessageWithTopLevelCwdAndRoot_CamelCase() throws {
        // Test that Message can parse top-level cwd and root fields (camelCase format)
        let json = """
        {
            "id": "msg_cwd_root_camel",
            "sessionID": "sess_cwd_test_camel",
            "role": "assistant",
            "time": { "created": "2026-01-27T12:00:00Z" },
            "cwd": "/Users/testuser/project",
            "root": "/Users/testuser"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: data)
        
        XCTAssertEqual(message.cwd, "/Users/testuser/project")
        XCTAssertEqual(message.root, "/Users/testuser")
    }
    
    func testMessageWithNestedPathObject() throws {
        // Test backward compatibility: nested path object format
        let json = """
        {
            "id": "msg_path_nested",
            "session_id": "sess_path_test",
            "role": "assistant",
            "time": { "created": "2026-01-27T12:00:00Z" },
            "path": {
                "cwd": "/workspace/app",
                "root": "/workspace"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: data)
        
        XCTAssertEqual(message.cwd, "/workspace/app")
        XCTAssertEqual(message.root, "/workspace")
    }
}

