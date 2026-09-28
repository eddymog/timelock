import XCTest
@testable import Timelock

final class TimeAggregationTests: XCTestCase {
    func testCompletedAndRunningSessionsContributeToTotal() {
        let now = Date(timeIntervalSince1970: 10_000)
        let completed = Session(startedAt: now.addingTimeInterval(-3_600))
        completed.endedAt = now.addingTimeInterval(-1_800)
        let running = Session(startedAt: now.addingTimeInterval(-600))

        XCTAssertEqual(totalTrackedDuration(for: [completed, running], at: now), 2_400)
    }

    func testNegativeDurationClampsToZero() {
        let now = Date(timeIntervalSince1970: 10_000)
        let session = Session(startedAt: now.addingTimeInterval(60))

        XCTAssertEqual(trackedDuration(for: session, at: now), 0)
    }

    func testDailyDurationClipsSessionAtMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)))
        let session = Session(startedAt: day.addingTimeInterval(-1_800))
        session.endedAt = day.addingTimeInterval(1_800)

        XCTAssertEqual(trackedDuration(on: day, for: [session], at: session.endedAt!, calendar: calendar), 1_800)
    }
}
