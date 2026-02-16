import Foundation

public protocol SyncScheduling {
    func start(interval: TimeInterval, handler: @escaping () -> Void)
    func stop()
}

public final class SyncScheduler: SyncScheduling {
    private var timer: DispatchSourceTimer?

    public init() {}

    public func start(interval: TimeInterval, handler: @escaping () -> Void) {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler(handler: handler)
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }
}
