import XCTest
import SwiftData
@testable import Timelock

@MainActor
final class TimerServiceTests: XCTestCase {
    private var context: ModelContext!
    private var clock: FakeClock!
    private var timer: TimerService!
    private var working: Activity!
    private var studying: Activity!

    override func setUpWithError() throws {
        context = try makeTestContext()
        clock = FakeClock()
        timer = TimerService(context: context, clock: clock)
        working = Activity(name: "Working", colorHex: "#FF0000")
        studying = Activity(name: "Studying", colorHex: "#0000FF")
        context.insert(working)
        context.insert(studying)
    }

    func testStartsIdle() {
        XCTAssertNil(timer.runningSession)
        XCTAssertEqual(timer.elapsed, 0)
    }

    func testStartCreatesRunningSessionAndPersistsIt() throws {
        try timer.start(working)

        let session = try XCTUnwrap(timer.runningSession)
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(session.startedAt, clock.now)
        XCTAssertTrue(session.activity === working)
        let stored = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(stored.count, 1)
    }

    func testElapsedIsNowMinusStartedAt() throws {
        try timer.start(working)
        clock.advance(by: 125)
        XCTAssertEqual(timer.elapsed, 125, accuracy: 0.001)
    }

    func testStopSetsEndedAtAndReturnsToIdle() throws {
        try timer.start(working)
        let session = try XCTUnwrap(timer.runningSession)
        clock.advance(by: 60)

        try timer.stop()

        XCTAssertEqual(session.endedAt, clock.now)
        XCTAssertNil(timer.runningSession)
        XCTAssertEqual(timer.elapsed, 0)
    }

    func testStartingSecondActivityStopsTheFirst() throws {
        try timer.start(working)
        let first = try XCTUnwrap(timer.runningSession)
        clock.advance(by: 30)

        try timer.start(studying)

        XCTAssertEqual(first.endedAt, clock.now)
        XCTAssertTrue(timer.runningSession?.activity === studying)
        let running = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil }))
        XCTAssertEqual(running.count, 1)
    }

    func testGentleSessionCanAlwaysStop() throws {
        try timer.start(working)
        XCTAssertTrue(timer.canStop)
    }

    func testStopWhenIdleDoesNothing() throws {
        try timer.stop()
        XCTAssertNil(timer.runningSession)
    }

    func testCommitmentSetsDeadlineAndPreventsStop() throws {
        try timer.start(working, minimumDuration: 600)

        XCTAssertEqual(timer.runningSession?.minimumEndAt, clock.now.addingTimeInterval(600))
        XCTAssertFalse(timer.canStop)
        XCTAssertEqual(timer.remainingCommitment, 600)
        XCTAssertThrowsError(try timer.stop()) { error in
            XCTAssertEqual(error as? TimerServiceError, .commitmentActive(remaining: 600))
        }
        XCTAssertNotNil(timer.runningSession)
    }

    func testCommitmentCanStopAfterDeadline() throws {
        try timer.start(working, minimumDuration: 600)
        clock.advance(by: 600)

        XCTAssertTrue(timer.canStop)
        try timer.stop()

        XCTAssertNil(timer.runningSession)
    }

    func testCommitmentRefusesActivitySwitch() throws {
        try timer.start(working, minimumDuration: 600)

        XCTAssertThrowsError(try timer.start(studying))
        XCTAssertTrue(timer.runningSession?.activity === working)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 1)
    }

    // MARK: Recovery (task 1.4)

    func testRecoverResumesUnfinishedSession() throws {
        let startedAt = clock.now
        let orphan = Session(startedAt: startedAt)
        orphan.activity = working
        context.insert(orphan)
        try context.save()
        clock.advance(by: 300)

        let relaunched = TimerService(context: context, clock: clock)
        relaunched.recoverOnLaunch()

        XCTAssertTrue(relaunched.runningSession === orphan)
        XCTAssertEqual(relaunched.elapsed, 300, accuracy: 0.001)
    }

    func testRecoverWithNoUnfinishedSessionStaysIdle() throws {
        let done = Session(startedAt: clock.now)
        done.endedAt = clock.now.addingTimeInterval(10)
        context.insert(done)
        try context.save()

        timer.recoverOnLaunch()

        XCTAssertNil(timer.runningSession)
    }

    func testRecoveredSessionCanBeStopped() throws {
        let orphan = Session(startedAt: clock.now)
        context.insert(orphan)
        try context.save()

        timer.recoverOnLaunch()
        clock.advance(by: 45)
        try timer.stop()

        XCTAssertEqual(orphan.endedAt, clock.now)
        XCTAssertNil(timer.runningSession)
    }

    func testRecoveryRestoresActiveCommitment() throws {
        let orphan = Session(
            startedAt: clock.now,
            minimumEndAt: clock.now.addingTimeInterval(600)
        )
        orphan.activity = working
        context.insert(orphan)
        try context.save()

        timer.recoverOnLaunch()

        XCTAssertFalse(timer.canStop)
        XCTAssertEqual(timer.remainingCommitment, 600)
        XCTAssertThrowsError(try timer.stop())
    }

    // MARK: Tick (task 1.5)

    func testElapsedChangeIsPublishedWhileRunning() throws {
        let ticking = TimerService(context: context, clock: clock, tickInterval: 0.05)
        try ticking.start(working)
        let changed = expectation(description: "elapsed observers notified")
        withObservationTracking {
            _ = ticking.elapsed
        } onChange: {
            changed.fulfill()
        }

        wait(for: [changed], timeout: 2)
        try ticking.stop()
    }

    func testTickingStopsWhenSessionStops() throws {
        let ticking = TimerService(context: context, clock: clock, tickInterval: 0.05)
        try ticking.start(working)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertGreaterThan(ticking.tick, 0)

        try ticking.stop()
        let ticksAtStop = ticking.tick
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        XCTAssertEqual(ticking.tick, ticksAtStop)
    }

    func testRecoveredSessionTicks() throws {
        context.insert(Session(startedAt: clock.now))
        try context.save()
        let ticking = TimerService(context: context, clock: clock, tickInterval: 0.05)

        ticking.recoverOnLaunch()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        XCTAssertGreaterThan(ticking.tick, 0)
        try ticking.stop()
    }

    // MARK: Blocking coordinator (Phase 2)

    func testStartAppliesActivityAppBlocks() throws {
        let blocker = TimerServiceFakeAppBlocker()
        let coordinator = BlockingCoordinator(appBlocker: blocker)
        let blockingTimer = TimerService(context: context, clock: clock, blockingCoordinator: coordinator)
        working.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord"))

        try blockingTimer.start(working)

        XCTAssertEqual(blocker.startedBundleIDs, ["com.hnc.Discord"])
        XCTAssertEqual(blocker.activityName, "Working")
    }

    func testStopClearsBlocks() throws {
        let blocker = TimerServiceFakeAppBlocker()
        let coordinator = BlockingCoordinator(appBlocker: blocker)
        let blockingTimer = TimerService(context: context, clock: clock, blockingCoordinator: coordinator)
        try blockingTimer.start(working)

        try blockingTimer.stop()

        XCTAssertTrue(blocker.didStop)
    }

    func testRecoverAppliesBlocksForRecoveredSession() throws {
        let blocker = TimerServiceFakeAppBlocker()
        let coordinator = BlockingCoordinator(appBlocker: blocker)
        working.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord"))
        let orphan = Session(startedAt: clock.now)
        orphan.activity = working
        context.insert(orphan)
        try context.save()

        let relaunched = TimerService(context: context, clock: clock, blockingCoordinator: coordinator)
        relaunched.recoverOnLaunch()

        XCTAssertEqual(blocker.startedBundleIDs, ["com.hnc.Discord"])
        XCTAssertEqual(blocker.activityName, "Working")
    }

    func testRecoverWithNoSessionChecksSetupAndClearsStaleWebsiteBlocks() async {
        let websiteBlocker = TimerServiceFakeWebsiteBlocker()
        let coordinator = BlockingCoordinator(
            appBlocker: TimerServiceFakeAppBlocker(),
            websiteBlocker: websiteBlocker
        )
        let relaunched = TimerService(context: context, clock: clock, blockingCoordinator: coordinator)

        relaunched.recoverOnLaunch()
        await coordinator.waitForPendingWebsiteOperations()

        XCTAssertEqual(websiteBlocker.statusCount, 1)
        XCTAssertEqual(websiteBlocker.unblockCount, 1)
    }

    // MARK: Persistence errors

    private struct SaveFailure: Error {}

    func testFailedSaveOnStartIsReportedButSessionStillRuns() throws {
        let errors = ErrorCenter()
        let failing = TimerService(context: context, clock: clock, errors: errors, save: { throw SaveFailure() })

        try failing.start(working)

        XCTAssertNotNil(failing.runningSession)
        XCTAssertNotNil(errors.current)
    }

    func testFailedSaveOnStopIsReportedButSessionStillEnds() throws {
        let errors = ErrorCenter()
        let failing = TimerService(context: context, clock: clock, errors: errors, save: { throw SaveFailure() })
        try failing.start(working)
        errors.dismiss()
        let session = try XCTUnwrap(failing.runningSession)

        try failing.stop()

        XCTAssertNotNil(session.endedAt)
        XCTAssertNil(failing.runningSession)
        XCTAssertNotNil(errors.current)
    }
}

private final class TimerServiceFakeAppBlocker: AppBlocking {
    private(set) var startedBundleIDs: [String] = []
    private(set) var activityName: String?
    private(set) var didStop = false

    func start(bundleIDs: [String], activityName: String) {
        startedBundleIDs = bundleIDs
        self.activityName = activityName
    }

    func stop() {
        didStop = true
    }
}

private final class TimerServiceFakeWebsiteBlocker: WebsiteBlocking {
    private(set) var statusCount = 0
    private(set) var unblockCount = 0

    func block(_ domains: [String]) async throws {}

    func unblock() async throws {
        unblockCount += 1
    }

    func status() async throws -> WebsiteBlockerStatus {
        statusCount += 1
        return .inactive
    }
}
