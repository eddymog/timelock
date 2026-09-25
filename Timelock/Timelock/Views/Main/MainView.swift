import SwiftUI
import SwiftData

struct MainView: View {
    let timer: TimerService
    @Environment(ErrorCenter.self) private var errors
    @Environment(\.openWindow) private var openWindow

    @Query(filter: #Predicate<Activity> { !$0.isArchived }, sort: \Activity.createdAt)
    private var activities: [Activity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = timer.runningSession {
                runningBlock(session)
                Divider()
            }

            VStack(spacing: 2) {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity, isRunning: timer.runningSession?.activity === activity) {
                        timer.start(activity)
                    }
                }
            }

            Divider()
            Button("Manage Activities…") {
                openWindow(id: WindowID.activities)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(minWidth: 300, maxWidth: 360)
        .errorAlert(errors)
    }

    private func runningBlock(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color(hex: session.activity?.colorHex ?? "")).frame(width: 10, height: 10)
                Text(session.activity?.name ?? "Running").font(.headline)
            }
            Text(DurationFormatter.hhmmss(timer.elapsed))
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .monospacedDigit()
            Button("Stop") { timer.stop() }
                .disabled(!timer.canStop)
        }
    }
}

private struct ActivityRow: View {
    let activity: Activity
    let isRunning: Bool
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack {
                Circle().fill(Color(hex: activity.colorHex)).frame(width: 10, height: 10)
                Text(activity.name)
                Spacer()
                Image(systemName: isRunning ? "record.circle" : "play.fill")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .accessibilityLabel(isRunning ? "\(activity.name), running" : "Start \(activity.name)")
    }
}
