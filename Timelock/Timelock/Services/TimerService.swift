import Foundation
import Observation
import SwiftData

/// Owns the running session. The only type that starts or stops one.
@Observable
final class TimerService {
    private(set) var runningSession: Session? {
        didSet { runningSession == nil ? stopTicking() : startTicking() }
    }
    /// Bumped every tick so views that read `elapsed` re-render. Display only.
    private(set) var tick = 0

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let tickInterval: TimeInterval
    @ObservationIgnored private let errors: ErrorCenter
    @ObservationIgnored private let save: () throws -> Void
    @ObservationIgnored private var ticker: Timer?

    init(
        context: ModelContext,
        clock: Clock = SystemClock(),
        tickInterval: TimeInterval = 1,
        errors: ErrorCenter = ErrorCenter(),
        save: (() throws -> Void)? = nil
    ) {
        self.context = context
        self.clock = clock
        self.tickInterval = tickInterval
        self.errors = errors
        self.save = save ?? { try context.save() }
    }

    /// Time since the running session started; always derived from timestamps.
    var elapsed: TimeInterval {
        _ = tick
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
        errors.perform("Saving the new session", save)
        runningSession = session
    }

    func stop() {
        guard let session = runningSession else { return }
        session.endedAt = clock.now
        errors.perform("Saving the stopped session", save)
        runningSession = nil
    }

    /// Resumes the session left running by a quit, crash or reboot.
    func recoverOnLaunch() {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            runningSession = try context.fetch(descriptor).first
        } catch {
            errors.report(error, while: "Restoring the running session")
        }
    }

    private func startTicking() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick += 1 }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
