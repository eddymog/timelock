import Foundation

func trackedDuration(for session: Session, at now: Date) -> TimeInterval {
    max(0, (session.endedAt ?? now).timeIntervalSince(session.startedAt))
}

func totalTrackedDuration(for sessions: [Session], at now: Date) -> TimeInterval {
    sessions.reduce(0) { $0 + trackedDuration(for: $1, at: now) }
}

func trackedDuration(
    on day: Date,
    for sessions: [Session],
    at now: Date,
    calendar: Calendar = .current
) -> TimeInterval {
    let dayStart = calendar.startOfDay(for: day)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

    return sessions.reduce(0) { total, session in
        let intervalStart = max(session.startedAt, dayStart)
        let intervalEnd = min(session.endedAt ?? now, dayEnd)
        return total + max(0, intervalEnd.timeIntervalSince(intervalStart))
    }
}
