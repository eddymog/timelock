import XCTest
@testable import Timelock

final class ReportAggregationTests: XCTestCase {
    private let interval = DateInterval(
        start: Date(timeIntervalSince1970: 1_000),
        end: Date(timeIntervalSince1970: 2_000)
    )

    func testSessionCrossingBothBoundariesIsClippedToInterval() {
        let session = Session(startedAt: Date(timeIntervalSince1970: 500))
        session.endedAt = Date(timeIntervalSince1970: 2_500)

        XCTAssertEqual(
            trackedDuration(in: interval, for: session, at: Date(timeIntervalSince1970: 3_000)),
            1_000
        )
    }

    func testRunningSessionEndsAtNow() {
        let session = Session(startedAt: Date(timeIntervalSince1970: 1_200))

        XCTAssertEqual(
            trackedDuration(in: interval, for: session, at: Date(timeIntervalSince1970: 1_500)),
            300
        )
    }

    func testEmptyRangeProducesNoActivityTotals() {
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        let session = Session(startedAt: Date(timeIntervalSince1970: 100))
        session.endedAt = Date(timeIntervalSince1970: 200)
        session.activity = activity

        XCTAssertTrue(activityDurations(
            for: [session],
            in: interval,
            at: Date(timeIntervalSince1970: 3_000)
        ).isEmpty)
    }

    func testSessionsAreSummedPerActivity() throws {
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        let first = Session(startedAt: Date(timeIntervalSince1970: 1_100))
        first.endedAt = Date(timeIntervalSince1970: 1_200)
        first.activity = activity
        let second = Session(startedAt: Date(timeIntervalSince1970: 1_300))
        second.endedAt = Date(timeIntervalSince1970: 1_500)
        second.activity = activity

        let totals = activityDurations(
            for: [first, second],
            in: interval,
            at: Date(timeIntervalSince1970: 3_000)
        )

        XCTAssertEqual(try XCTUnwrap(totals[activity.id]), 300)
    }

    func testReportIntervalsUseCalendarBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12)))

        let day = try XCTUnwrap(reportInterval(containing: date, period: .day, calendar: calendar))
        let week = try XCTUnwrap(reportInterval(containing: date, period: .week, calendar: calendar))
        let month = try XCTUnwrap(reportInterval(containing: date, period: .month, calendar: calendar))

        XCTAssertEqual(day.duration, 86_400)
        XCTAssertEqual(week.duration, 7 * 86_400)
        XCTAssertEqual(calendar.component(.day, from: week.start), 28)
        XCTAssertEqual(calendar.component(.month, from: month.start), 9)
        XCTAssertEqual(calendar.component(.month, from: month.end), 10)
    }
}
