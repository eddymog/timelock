import XCTest
@testable import Timelock

final class ClockTests: XCTestCase {

    func testSystemClockReturnsCurrentTime() {
        let before = Date()
        let now = SystemClock().now
        let after = Date()
        XCTAssertGreaterThanOrEqual(now, before)
        XCTAssertLessThanOrEqual(now, after)
    }

    func testFakeClockAdvancesOnlyWhenTold() {
        let clock = FakeClock(Date(timeIntervalSince1970: 500))
        XCTAssertEqual(clock.now, Date(timeIntervalSince1970: 500))
        clock.advance(by: 90)
        XCTAssertEqual(clock.now, Date(timeIntervalSince1970: 590))
    }
}
