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
}
