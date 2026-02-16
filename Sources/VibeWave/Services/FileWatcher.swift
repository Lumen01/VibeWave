import Foundation
import Combine
import CoreServices
import os

public struct FileSystemEvent {
    public let filePath: String
    public let eventType: FileSystemEventType
    public let timestamp: Date
    
    public init(filePath: String, eventType: FileSystemEventType, timestamp: Date = Date()) {
        self.filePath = filePath
        self.eventType = eventType

        self.timestamp = timestamp

    }
}

public enum FileSystemEventType {
    case added
    case modified
    case deleted

}

public protocol FileWatching {
    var detectedEventsPublisher: AnyPublisher<[FileSystemEvent], Never> { get }
    func startWatching(directory url: URL)
    func stopWatching()
}

public final class FileWatcher: FileWatching {
    @Published public var detectedEvents: [FileSystemEvent] = []

    public var detectedEventsPublisher: AnyPublisher<[FileSystemEvent], Never> {
        $detectedEvents.eraseToAnyPublisher()
    }

    private var eventStream: FSEventStreamRef?
    private var checkTimer: DispatchSourceTimer?
    private let flushInterval: TimeInterval
    private var pendingEvents: Set<String> = []
    private var watchedPaths: [String] = []
    private let eventQueue = DispatchQueue(label: "FileWatcher.FSEvents", qos: .userInitiated)
    private let pendingEventsQueue = DispatchQueue(label: "FileWatcher.PendingEvents")
    private let timerQueue = DispatchQueue(label: "FileWatcher.Timer", qos: .utility)
    private let logger = AppLogger(category: "FileWatcher")
    
    public init(flushInterval: TimeInterval = 5.0) {
        self.flushInterval = flushInterval
    }
    
    public func startWatching(directory url: URL) {
        let resolvedPath = url.resolvingSymlinksInPath().path
        logger.debug("Starting file watcher for directory: \(resolvedPath)")
        let wasAdded = !watchedPaths.contains(resolvedPath)
        if wasAdded {
            watchedPaths.append(resolvedPath)
            restartEventStream()
        }

        startTimerIfNeeded()
    }
    
    public func stopWatching() {
        stopEventStream()
        watchedPaths.removeAll()

        pendingEventsQueue.sync {
            pendingEvents.removeAll()
        }

        checkTimer?.cancel()
        checkTimer = nil
    }

    
    deinit {
        stopWatching()

    }

}

private extension FileWatcher {
    func startTimerIfNeeded() {
        guard checkTimer == nil else { return }
        guard checkTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + flushInterval, repeating: flushInterval)
        timer.setEventHandler { [weak self] in
            self?.flushPendingEvents()
        }
        timer.resume()
        checkTimer = timer
    }

    func flushPendingEvents() {
        var paths: [String] = []
        pendingEventsQueue.sync {
            if !pendingEvents.isEmpty {
                paths = Array(pendingEvents)
                pendingEvents.removeAll()
            }
        }
        guard !paths.isEmpty else { return }

        let events = paths.map { filePath in
            FileSystemEvent(filePath: filePath, eventType: .modified, timestamp: Date())
        }
        DispatchQueue.main.async { [weak self] in
            self?.detectedEvents = events
        }
    }

    func restartEventStream() {
        stopEventStream()
        guard !watchedPaths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagUseCFTypes
        )
        let latency: CFTimeInterval = 0.3

        guard let stream = FSEventStreamCreate(
            nil,
            FileWatcher.eventCallback,
            &context,
            watchedPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            logger.error("Failed to create FSEvents stream for: \(watchedPaths.joined(separator: ", "))")
            return
        }

        eventStream = stream
        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
    }

    func stopEventStream() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    func handleEvent(path: String, flags: FSEventStreamEventFlags) {
        let isDirectory = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0
        if isDirectory { return }
        guard isSupportedSyncFile(path: path) else { return }

        let isRemoved = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
        if isRemoved { return }

        let normalizedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        pendingEventsQueue.async { [weak self] in
            self?.pendingEvents.insert(normalizedPath)
        }

        logger.debug("Detected file event: \(normalizedPath)")
    }

    func isSupportedSyncFile(path: String) -> Bool {
        if path.hasSuffix(".json") {
            return true
        }

        let filename = URL(fileURLWithPath: path).lastPathComponent
        return filename == "opencode.db" || filename == "opencode.db-wal" || filename == "opencode.db-shm"
    }

    static let eventCallback: FSEventStreamCallback = { _, info, count, eventPathsPointer, eventFlagsPointer, _ in
        guard let info = info else { return }
        let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
        let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPathsPointer).takeUnretainedValue()
        let paths = cfPaths as? [String] ?? []
        let eventCount = min(count, paths.count)

        for index in 0..<eventCount {
            let path = paths[index]
            let flags = eventFlagsPointer[index]
            watcher.handleEvent(path: path, flags: flags)
        }
    }
}
