import XCTest
@testable import VibeWave

final class SummaryFieldTests: XCTestCase {
    func testMessageWithSummaryParsing() throws {
        let json = """
        {
            "id": "msg_summary_001",
            "session_id": "sess_123",
            "role": "assistant",
            "time": { "created": "2026-01-27T12:00:00Z" },
            "summary": {
                "title": "实现新功能",
                "diffs": [
                    {
                        "file": "src/main.swift",
                        "before": "旧内容",
                        "after": "新内容",
                        "additions": 5,
                        "deletions": 2
                    },
                    {
                        "file": "src/helper.swift",
                        "additions": 3,
                        "deletions": 1
                    }
                ]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let message = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(message.id, "msg_summary_001")
            XCTAssertNotNil(message.summary)
            XCTAssertEqual(message.summary?.title, "实现新功能")
            XCTAssertEqual(message.summary?.diffs?.count, 2)
            XCTAssertEqual(message.summary?.totalAdditions, 8)
            XCTAssertEqual(message.summary?.totalDeletions, 3)
            XCTAssertEqual(message.summary?.fileCount, 2)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }
    
    func testMessageWithoutSummary() throws {
        let json = """
        {
            "id": "msg_no_summary_001",
            "session_id": "sess_124",
            "role": "user",
            "time": { "created": "2026-01-27T12:00:00Z" }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let message = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(message.id, "msg_no_summary_001")
            XCTAssertNil(message.summary)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }
    
    func testSessionSummaryWithEmptyDiffs() throws {
        let json = """
        {
            "title": "空变更",
            "diffs": []
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let summary = try decoder.decode(SessionSummary.self, from: data)
            XCTAssertEqual(summary.title, "空变更")
            XCTAssertEqual(summary.diffs?.count, 0)
            XCTAssertEqual(summary.totalAdditions, 0)
            XCTAssertEqual(summary.totalDeletions, 0)
            XCTAssertEqual(summary.fileCount, 0)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }
    
    func testFileDiffPartialFields() throws {
        let json = """
        {
            "title": "部分字段",
            "diffs": [
                {
                    "file": "test.swift",
                    "additions": 10
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let summary = try decoder.decode(SessionSummary.self, from: data)
            XCTAssertEqual(summary.title, "部分字段")
            XCTAssertEqual(summary.diffs?.first?.file, "test.swift")
            XCTAssertEqual(summary.diffs?.first?.additions, 10)
            XCTAssertNil(summary.diffs?.first?.deletions)
            XCTAssertNil(summary.diffs?.first?.before)
            XCTAssertNil(summary.diffs?.first?.after)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }
    
    func testMessageRecordSummaryMapping() throws {
        let message = Message(
            id: "test_msg",
            sessionID: "test_session",
            role: "assistant",
            time: MessageTime(created: "2026-01-27T12:00:00Z", completed: nil),
            parentID: nil,
            providerID: "provider",
            modelID: "model",
            agent: "agent",
            mode: "auto",
            variant: "v1",
            cwd: "/workspace",
            root: "/",
            tokens: Tokens(input: 10, output: 20, reasoning: 5),
            cost: 0.5,
            summary: SessionSummary(
                title: "测试总结",
                diffs: [
                    SessionSummary.FileDiff(file: "file1.swift", additions: 5, deletions: 2),
                    SessionSummary.FileDiff(file: "file2.swift", additions: 3, deletions: 1)
                ]
            )
        )
        
        let record = MessageRecord(message)
        XCTAssertEqual(record.summaryTitle, "测试总结")
        XCTAssertEqual(record.summaryTotalAdditions, 8)
        XCTAssertEqual(record.summaryTotalDeletions, 3)
        XCTAssertEqual(record.summaryFileCount, 2)
        let files = record.diffFiles?.split(separator: ",").sorted()
        XCTAssertEqual(files, ["file1.swift", "file2.swift"])
    }

    func testMessageRecordWithoutSummary() throws {
        let message = Message(
            id: "test_msg_no_summary",
            sessionID: "test_session",
            role: "user",
            time: MessageTime(created: "2026-01-27T12:00:00Z", completed: nil),
            parentID: nil,
            providerID: "provider",
            modelID: "model",
            agent: nil,
            mode: nil,
            variant: nil,
            cwd: nil,
            root: nil,
            tokens: nil,
            cost: nil
        )

        let record = MessageRecord(message)
        XCTAssertNil(record.summaryTitle)
        XCTAssertEqual(record.summaryTotalAdditions, 0)
        XCTAssertEqual(record.summaryTotalDeletions, 0)
        XCTAssertEqual(record.summaryFileCount, 0)
        XCTAssertNil(record.diffFiles)
    }

    func testDiffFilesDeduplication() throws {
        let message = Message(
            id: "test_msg_dedup",
            sessionID: "test_session",
            role: "assistant",
            time: MessageTime(created: "2026-01-27T12:00:00Z", completed: nil),
            parentID: nil,
            providerID: "provider",
            modelID: "model",
            agent: "agent",
            mode: "auto",
            variant: "v1",
            cwd: "/workspace",
            root: "/",
            tokens: Tokens(input: 10, output: 20, reasoning: 5),
            cost: 0.5,
            summary: SessionSummary(
                title: "重复文件测试",
                diffs: [
                    SessionSummary.FileDiff(file: "file1.swift", additions: 5, deletions: 2),
                    SessionSummary.FileDiff(file: "file1.swift", additions: 3, deletions: 1),
                    SessionSummary.FileDiff(file: "file2.swift", additions: 4, deletions: 0)
                ]
            )
        )

        let record = MessageRecord(message)
        XCTAssertEqual(record.summaryFileCount, 3)
        let files = record.diffFiles?.split(separator: ",").sorted()
        XCTAssertEqual(files, ["file1.swift", "file2.swift"])
    }
}