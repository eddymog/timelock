import AppKit
import SwiftUI
import SwiftData

struct MainView: View {
    let timer: TimerService
    let blockingCoordinator: BlockingCoordinator
    private let browserController = BrowserController()
    @Environment(ErrorCenter.self) private var errors
    @State private var selection: MainSection? = .timer
    @State private var pendingBrowserClose: PendingBrowserClose?

    @Query(filter: #Predicate<Activity> { !$0.isArchived }, sort: \Activity.createdAt)
    private var activities: [Activity]
    @Query(filter: #Predicate<BlockGroup> { $0.isGlobal })
    private var globalGroups: [BlockGroup]
    @Query private var sessions: [Session]

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Timelock")
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
        } detail: {
            switch selection ?? .timer {
            case .timer:
                timerView
            case .activities:
                ActivityEditorView()
                    .navigationTitle("Activities")
            case .history:
                HistoryView(timer: timer)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .errorAlert(errors)
        .alert(
            "Close browser before starting?",
            isPresented: Binding(
                get: { pendingBrowserClose != nil },
                set: { if !$0 { pendingBrowserClose = nil } }
            ),
            presenting: pendingBrowserClose
        ) { request in
            Button("Cancel", role: .cancel) {
                pendingBrowserClose = nil
            }
            Button("Start Without Closing") {
                pendingBrowserClose = nil
                timer.start(request.activity)
            }
            Button("Close and Start") {
                pendingBrowserClose = nil
                Task { await closeBrowsersAndStart(request) }
            }
        } message: { request in
            Text("Closing \(request.browserNames) prevents existing connections from bypassing website blocking. You can also start without closing it.")
        }
    }

    private var timerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let warning = blockingCoordinator.websiteWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Warning: \(warning)")
            }

            if let session = timer.runningSession {
                runningBlock(session)
                Divider()
            }

            HStack {
                Text("Today")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DurationFormatter.hhmmss(todayTotal))
                    .font(.headline)
                    .monospacedDigit()
            }

            Divider()
            Text("Activities")
                .font(.headline)

            VStack(spacing: 2) {
                ForEach(activities) { activity in
                    ActivityRow(
                        activity: activity,
                        isRunning: timer.runningSession?.activity === activity,
                        total: totalTrackedDuration(for: activity.sessions, at: currentTime)
                    ) {
                        requestStart(activity)
                    }
                }
            }

            Spacer()
            Button {
                selection = .activities
            } label: {
                Label("Manage Activities", systemImage: "slider.horizontal.3")
            }
        }
        .padding(16)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Timer")
    }

    private var currentTime: Date {
        _ = timer.tick
        return Date()
    }

    private var todayTotal: TimeInterval {
        trackedDuration(on: currentTime, for: sessions, at: currentTime)
    }

    private func requestStart(_ activity: Activity) {
        let hasWebsiteRules = effectiveRules(for: activity, globalGroups: globalGroups)
            .contains { $0.kind == .website }
        guard hasWebsiteRules else {
            timer.start(activity)
            return
        }

        let browsers = browserController.runningBrowsers()
        guard !browsers.isEmpty else {
            timer.start(activity)
            return
        }
        pendingBrowserClose = PendingBrowserClose(activity: activity, browsers: browsers)
    }

    private func closeBrowsersAndStart(_ request: PendingBrowserClose) async {
        do {
            try await browserController.close(request.browsers)
            timer.start(request.activity)
        } catch {
            errors.report(error, while: "Closing the browser")
        }
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

private struct PendingBrowserClose: Identifiable {
    let id = UUID()
    let activity: Activity
    let browsers: [NSRunningApplication]

    var browserNames: String {
        ListFormatter.localizedString(byJoining: browsers.compactMap(\.localizedName))
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case timer
    case activities
    case history

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .timer: "timer"
        case .activities: "list.bullet"
        case .history: "clock.arrow.circlepath"
        }
    }
}

private struct ActivityRow: View {
    let activity: Activity
    let isRunning: Bool
    let total: TimeInterval
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack {
                Circle().fill(Color(hex: activity.colorHex)).frame(width: 10, height: 10)
                Text(activity.name)
                Spacer()
                Text(DurationFormatter.hhmmss(total))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
