import Foundation
import Observation
import SwiftData

/// Owns the running session. The only type that starts or stops one.
@Observable
@MainActor
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
    @ObservationIgnored private let blockingCoordinator: BlockingCoordinator?
    @ObservationIgnored private let save: () throws -> Void
    @ObservationIgnored private var ticker: Timer?

    init(
        context: ModelContext,
        clock: Clock? = nil,
        tickInterval: TimeInterval = 1,
        errors: ErrorCenter? = nil,
        blockingCoordinator: BlockingCoordinator? = nil,
        save: (() throws -> Void)? = nil
    ) {
        self.context = context
        self.clock = clock ?? SystemClock()
        self.tickInterval = tickInterval
        self.errors = errors ?? ErrorCenter()
        self.blockingCoordinator = blockingCoordinator
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

    var remainingCommitment: TimeInterval {
        _ = tick
        guard let minimumEndAt = runningSession?.minimumEndAt else { return 0 }
        return max(0, minimumEndAt.timeIntervalSince(clock.now))
    }

    func start(_ activity: Activity, minimumDuration: TimeInterval? = nil) throws {
        try stop()
        let duration = max(0, minimumDuration ?? 0)
        let session = Session(
            startedAt: clock.now,
            minimumEndAt: duration > 0 ? clock.now.addingTimeInterval(duration) : nil
        )
        session.activity = activity
        context.insert(session)
        errors.perform("Saving the new session", save)
        runningSession = session
        applyBlocks(for: activity)
    }

    func stop() throws {
        guard let session = runningSession else { return }
        guard canStop else {
            throw TimerServiceError.commitmentActive(remaining: remainingCommitment)
        }
        session.endedAt = clock.now
        errors.perform("Saving the stopped session", save)
        runningSession = nil
        blockingCoordinator?.clear()
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
            if let activity = runningSession?.activity {
                applyBlocks(for: activity)
            } else {
                blockingCoordinator?.prepareForIdleLaunch()
            }
        } catch {
            errors.report(error, while: "Restoring the running session")
        }
    }

    private func applyBlocks(for activity: Activity) {
        do {
            let globalGroups = try context.fetch(FetchDescriptor<BlockGroup>(predicate: #Predicate { $0.isGlobal }))
            blockingCoordinator?.apply(activity: activity, globalGroups: globalGroups)
        } catch {
            errors.report(error, while: "Loading block rules")
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

enum TimerServiceError: LocalizedError, Equatable {
    case commitmentActive(remaining: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .commitmentActive(let remaining):
            "Commitment is active for another \(DurationFormatter.hhmmss(remaining))."
        }
    }
}
