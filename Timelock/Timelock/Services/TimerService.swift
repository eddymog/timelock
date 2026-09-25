import Foundation
import Observation
import SwiftData

/// Owns the running session. The only type that starts or stops one.
@Observable
final class TimerService {
    private(set) var runningSession: Session?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: Clock

    init(context: ModelContext, clock: Clock = SystemClock()) {
        self.context = context
        self.clock = clock
    }

    /// Time since the running session started; always derived from timestamps.
    var elapsed: TimeInterval {
        guard let session = runningSession else { return 0 }
        return clock.now.timeIntervalSince(session.startedAt)
    }

    var canStop: Bool {
        guard let session = runningSession else { return false }
        guard let minimumEndAt = session.minimumEndAt else { return true }
        return clock.now >= minimumEndAt
    }

    func start(_ activity: Activity) {
        stop()
        let session = Session(startedAt: clock.now)
        session.activity = activity
        context.insert(session)
        try? context.save()
        runningSession = session
    }

    func stop() {
        guard let session = runningSession else { return }
        session.endedAt = clock.now
        try? context.save()
        runningSession = nil
    }
}
