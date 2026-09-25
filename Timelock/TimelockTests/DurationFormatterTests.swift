import XCTest
@testable import Timelock

final class DurationFormatterTests: XCTestCase {

    func testFormatsHHMMSS() {
        let cases: [(TimeInterval, String)] = [
            (0, "00:00:00"),
            (59, "00:00:59"),
            (60, "00:01:00"),
            (3661, "01:01:01"),
            (86_399, "23:59:59"),
            (90_000, "25:00:00"),      // hours do not wrap past a day
            (61.9, "00:01:01"),        // fractions truncate
            (-5, "00:00:00"),          // negatives clamp
        ]
        for (seconds, expected) in cases {
            XCTAssertEqual(DurationFormatter.hhmmss(seconds), expected, "\(seconds)s")
        }
    }
}
