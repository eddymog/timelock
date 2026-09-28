import XCTest
@testable import Timelock

final class SessionEntryValidatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testAcceptsCompletedPastInterval() throws {
        XCTAssertNoThrow(try SessionEntryValidator.validate(
            startedAt: now.addingTimeInterval(-3_600),
            endedAt: now.addingTimeInterval(-1_800),
            now: now,
            runningSession: nil
        ))
    }

    func testRejectsEndBeforeOrEqualToStart() {
        XCTAssertThrowsError(try SessionEntryValidator.validate(
            startedAt: now,
            endedAt: now,
            now: now,
            runningSession: nil
        )) { error in
            XCTAssertEqual(error as? SessionEntryValidationError, .endNotAfterStart)
        }
    }

    func testRejectsFutureEnd() {
        XCTAssertThrowsError(try SessionEntryValidator.validate(
            startedAt: now,
            endedAt: now.addingTimeInterval(60),
            now: now,
            runningSession: nil
        )) { error in
            XCTAssertEqual(error as? SessionEntryValidationError, .endInFuture)
        }
    }

    func testRejectsOverlapWithRunningSession() {
        let running = Session(startedAt: now.addingTimeInterval(-600))

        XCTAssertThrowsError(try SessionEntryValidator.validate(
            startedAt: now.addingTimeInterval(-1_200),
            endedAt: now.addingTimeInterval(-300),
            now: now,
            runningSession: running
        )) { error in
            XCTAssertEqual(error as? SessionEntryValidationError, .overlapsRunningSession)
        }
    }

    func testAcceptsIntervalEndingWhenRunningSessionStarts() throws {
        let running = Session(startedAt: now.addingTimeInterval(-600))

        XCTAssertNoThrow(try SessionEntryValidator.validate(
            startedAt: now.addingTimeInterval(-1_200),
            endedAt: running.startedAt,
            now: now,
            runningSession: running
        ))
    }
}
