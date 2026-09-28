import XCTest
@testable import Timelock

final class NotificationThrottleTests: XCTestCase {
    func testRepeatedNotificationIsSuppressedDuringCooldown() {
        var throttle = NotificationThrottle(cooldown: 10)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(throttle.shouldPost(key: "Working|Discord", at: now))
        XCTAssertFalse(throttle.shouldPost(key: "Working|Discord", at: now.addingTimeInterval(9)))
        XCTAssertTrue(throttle.shouldPost(key: "Working|Discord", at: now.addingTimeInterval(10)))
    }

    func testDifferentAppsDoNotSuppressEachOther() {
        var throttle = NotificationThrottle(cooldown: 10)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(throttle.shouldPost(key: "Working|Discord", at: now))
        XCTAssertTrue(throttle.shouldPost(key: "Working|Messages", at: now))
    }
}
