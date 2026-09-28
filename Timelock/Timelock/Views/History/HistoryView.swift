import SwiftData
import SwiftUI

struct HistoryView: View {
    let timer: TimerService
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        let now = currentTime
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("All Time")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(DurationFormatter.hhmmss(totalTrackedDuration(for: sessions, at: now)))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(16)

            Divider()

            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "clock",
                    description: Text("Completed activities will appear here.")
                )
            } else {
                List {
                    ForEach(historyDays, id: \.self) { day in
                        let daySessions = sessionsByDay[day] ?? []
                        Section {
                            ForEach(daySessions) { session in
                                HistoryRow(session: session, now: now)
                            }
                        } header: {
                            HStack {
                                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                                Spacer()
                                Text(DurationFormatter.hhmmss(totalTrackedDuration(for: daySessions, at: now)))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("History")
    }

    private var currentTime: Date {
        _ = timer.tick
        return Date()
    }

    private var sessionsByDay: [Date: [Session]] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.startedAt) }
    }

    private var historyDays: [Date] {
        sessionsByDay.keys.sorted(by: >)
    }
}

private struct HistoryRow: View {
    let session: Session
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: session.activity?.colorHex ?? ""))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.activity?.name ?? "Deleted Activity")
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationFormatter.hhmmss(trackedDuration(for: session, at: now)))
                .monospacedDigit()
            if session.endedAt == nil {
                Text("Running")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 3)
    }

    private var timeRange: String {
        let start = session.startedAt.formatted(date: .omitted, time: .shortened)
        guard let endedAt = session.endedAt else { return "\(start)–now" }
        return "\(start)–\(endedAt.formatted(date: .omitted, time: .shortened))"
    }
}
