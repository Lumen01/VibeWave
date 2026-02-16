import XCTest
import Combine
@testable import VibeWave

final class FileWatcherRecursiveTests: XCTestCase {
    func testFileWatcher_EmitsEventsForNestedJson() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let watcher = FileWatcher(flushInterval: 0.1)
        let expectation = expectation(description: "nested json event")

        let fileURL = nested.appendingPathComponent("msg.json")
        let expectedPath = fileURL.resolvingSymlinksInPath().path
        var cancellable: AnyCancellable?

        cancellable = watcher.detectedEventsPublisher
            .sink { events in
                if events.contains(where: { $0.filePath == expectedPath }) {
                    expectation.fulfill()
                }
            }

        watcher.startWatching(directory: root)

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            try? "{}".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        wait(for: [expectation], timeout: 3.0)

        cancellable?.cancel()
        watcher.stopWatching()
    }
}
