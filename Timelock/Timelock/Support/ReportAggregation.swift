import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: Self { self }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

func reportInterval(
    containing date: Date,
    period: ReportPeriod,
    calendar: Calendar = .current
) -> DateInterval? {
    switch period {
    case .day:
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    case .week:
        return calendar.dateInterval(of: .weekOfYear, for: date)
    case .month:
        return calendar.dateInterval(of: .month, for: date)
    }
}

func trackedDuration(
    in interval: DateInterval,
    for session: Session,
    at now: Date
) -> TimeInterval {
    let intervalStart = max(session.startedAt, interval.start)
    let sessionEnd = min(session.endedAt ?? now, now)
    let intervalEnd = min(sessionEnd, interval.end)
    return max(0, intervalEnd.timeIntervalSince(intervalStart))
}

func activityDurations(
    for sessions: [Session],
    in interval: DateInterval,
    at now: Date
) -> [UUID: TimeInterval] {
    sessions.reduce(into: [:]) { totals, session in
        guard let activityID = session.activity?.id else { return }
        let duration = trackedDuration(in: interval, for: session, at: now)
        guard duration > 0 else { return }
        totals[activityID, default: 0] += duration
    }
}
