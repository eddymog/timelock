import SwiftUI

/// Menu bar title: a clock when idle, `● Working 01:23:45` while running.
struct MenuBarLabel: View {
    let timer: TimerService

    var body: some View {
        if let session = timer.runningSession {
            Text("● \(session.activity?.name ?? "Running") \(DurationFormatter.hhmmss(timer.elapsed))")
                .monospacedDigit()
        } else {
            Image(systemName: "clock")
        }
    }
}
