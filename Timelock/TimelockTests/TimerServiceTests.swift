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
        timer.start(working)

        let session = try XCTUnwrap(timer.runningSession)
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(session.startedAt, clock.now)
        XCTAssertTrue(session.activity === working)
        let stored = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(stored.count, 1)
    }

    func testElapsedIsNowMinusStartedAt() {
        timer.start(working)
        clock.advance(by: 125)
        XCTAssertEqual(timer.elapsed, 125, accuracy: 0.001)
    }

    func testStopSetsEndedAtAndReturnsToIdle() throws {
        timer.start(working)
        let session = try XCTUnwrap(timer.runningSession)
        clock.advance(by: 60)

        timer.stop()

        XCTAssertEqual(session.endedAt, clock.now)
        XCTAssertNil(timer.runningSession)
        XCTAssertEqual(timer.elapsed, 0)
    }

    func testStartingSecondActivityStopsTheFirst() throws {
        timer.start(working)
        let first = try XCTUnwrap(timer.runningSession)
        clock.advance(by: 30)

        timer.start(studying)

        XCTAssertEqual(first.endedAt, clock.now)
        XCTAssertTrue(timer.runningSession?.activity === studying)
        let running = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil }))
        XCTAssertEqual(running.count, 1)
    }

    func testGentleSessionCanAlwaysStop() {
        timer.start(working)
        XCTAssertTrue(timer.canStop)
    }

    func testStopWhenIdleDoesNothing() {
        timer.stop()
        XCTAssertNil(timer.runningSession)
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
        timer.stop()

        XCTAssertEqual(orphan.endedAt, clock.now)
        XCTAssertNil(timer.runningSession)
    }

    // MARK: Tick (task 1.5)

    func testElapsedChangeIsPublishedWhileRunning() {
        let ticking = TimerService(context: context, clock: clock, tickInterval: 0.05)
        ticking.start(working)
        let changed = expectation(description: "elapsed observers notified")
        withObservationTracking {
            _ = ticking.elapsed
        } onChange: {
            changed.fulfill()
        }

        wait(for: [changed], timeout: 2)
        ticking.stop()
    }

    func testTickingStopsWhenSessionStops() {
        let ticking = TimerService(context: context, clock: clock, tickInterval: 0.05)
        ticking.start(working)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertGreaterThan(ticking.tick, 0)

        ticking.stop()
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
        ticking.stop()
    }
}
