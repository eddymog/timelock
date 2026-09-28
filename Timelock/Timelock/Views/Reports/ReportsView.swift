import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    let timer: TimerService

    @Query private var sessions: [Session]
    @Query(sort: \Activity.createdAt) private var activities: [Activity]
    @State private var period: ReportPeriod = .week
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(16)
            Divider()

            if rows.isEmpty {
                ContentUnavailableView(
                    "No Time Recorded",
                    systemImage: "chart.bar.xaxis",
                    description: Text("There are no sessions in this \(period.rawValue.lowercased()).")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Total")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text(DurationFormatter.hhmmss(reportTotal))
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            Spacer()
                            Text(rangeTitle)
                                .foregroundStyle(.secondary)
                        }

                        Chart(rows) { row in
                            BarMark(
                                x: .value("Hours", row.duration / 3_600),
                                y: .value("Activity", row.name)
                            )
                            .foregroundStyle(row.color)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text(DurationFormatter.hhmmss(row.duration))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxisLabel("Hours")
                        .chartLegend(.hidden)
                        .frame(height: max(220, CGFloat(rows.count) * 42))
                        .padding(.trailing, 76)
                        .accessibilityLabel("Time per activity")

                        Divider()

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Activity Totals")
                                .font(.headline)
                                .padding(.bottom, 8)
                            ForEach(rows) { row in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(row.color)
                                        .frame(width: 9, height: 9)
                                    Text(row.name)
                                    Spacer()
                                    Text(DurationFormatter.hhmmss(row.duration))
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 7)
                                if row.id != rows.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Reports")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Period", selection: $period) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Spacer()

            Button {
                movePeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Previous \(period.rawValue.lowercased())")

            Button("Today") {
                selectedDate = Date()
            }

            Button {
                movePeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("Next \(period.rawValue.lowercased())")
            .disabled(isCurrentPeriod)
        }
    }

    private var currentTime: Date {
        _ = timer.tick
        return Date()
    }

    private var selectedInterval: DateInterval {
        reportInterval(containing: selectedDate, period: period) ?? DateInterval(start: selectedDate, duration: 0)
    }

    private var rows: [ReportRow] {
        let totals = activityDurations(for: sessions, in: selectedInterval, at: currentTime)
        return activities.compactMap { activity in
            guard let duration = totals[activity.id], duration > 0 else { return nil }
            return ReportRow(
                id: activity.id,
                name: activity.name,
                color: Color(hex: activity.colorHex),
                duration: duration
            )
        }
        .sorted {
            $0.duration == $1.duration ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.duration > $1.duration
        }
    }

    private var reportTotal: TimeInterval {
        rows.reduce(0) { $0 + $1.duration }
    }

    private var isCurrentPeriod: Bool {
        selectedInterval.contains(currentTime)
    }

    private var rangeTitle: String {
        let interval = selectedInterval
        let inclusiveEnd = interval.end.addingTimeInterval(-1)
        switch period {
        case .day:
            return interval.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
        case .week:
            let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let end = inclusiveEnd.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(start) - \(end)"
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        }
    }

    private func movePeriod(by amount: Int) {
        if let date = Calendar.current.date(byAdding: period.calendarComponent, value: amount, to: selectedDate) {
            selectedDate = date
        }
    }
}

private struct ReportRow: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    let duration: TimeInterval
}
