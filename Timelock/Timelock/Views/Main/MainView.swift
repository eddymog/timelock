import AppKit
import SwiftUI
import SwiftData

struct MainView: View {
    let timer: TimerService
    let blockingCoordinator: BlockingCoordinator
    let settings: AppSettings
    private let browserController = BrowserController()
    @Environment(ErrorCenter.self) private var errors
    @State private var selection: MainSection? = .timer
    @State private var pendingBrowserClose: PendingBrowserClose?
    @State private var pendingStart: Activity?

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
            case .groups:
                GroupEditorView()
            case .history:
                HistoryView(timer: timer)
            case .reports:
                ReportsView(timer: timer)
            case .settings:
                SettingsView(settings: settings, blockingCoordinator: blockingCoordinator)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .errorAlert(errors)
        .sheet(item: $pendingStart) { activity in
            StartActivitySheet(activity: activity, defaultCommitment: settings.defaultCommitment) { duration in
                pendingStart = nil
                prepareStart(activity, minimumDuration: duration)
            }
        }
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
                start(request)
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
        guard timer.runningSession == nil || timer.canStop else {
            errors.report(
                TimerServiceError.commitmentActive(remaining: timer.remainingCommitment),
                while: "Starting \(activity.name)"
            )
            return
        }
        pendingStart = activity
    }

    private func prepareStart(_ activity: Activity, minimumDuration: TimeInterval?) {
        let hasWebsiteRules = effectiveRules(for: activity, globalGroups: globalGroups)
            .contains { $0.kind == .website }
        guard hasWebsiteRules else {
            start(PendingBrowserClose(activity: activity, minimumDuration: minimumDuration, browsers: []))
            return
        }

        let browsers = browserController.runningBrowsers()
        guard !browsers.isEmpty else {
            start(PendingBrowserClose(activity: activity, minimumDuration: minimumDuration, browsers: []))
            return
        }

        let request = PendingBrowserClose(
            activity: activity,
            minimumDuration: minimumDuration,
            browsers: browsers
        )
        switch settings.browserStartBehavior {
        case .ask:
            pendingBrowserClose = request
        case .close:
            Task { await closeBrowsersAndStart(request) }
        case .keepOpen:
            start(request)
        }
    }

    private func closeBrowsersAndStart(_ request: PendingBrowserClose) async {
        do {
            try await browserController.close(request.browsers)
            start(request)
        } catch {
            errors.report(error, while: "Closing the browser")
        }
    }

    private func start(_ request: PendingBrowserClose) {
        do {
            try timer.start(request.activity, minimumDuration: request.minimumDuration)
        } catch {
            errors.report(error, while: "Starting \(request.activity.name)")
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
            if session.minimumEndAt != nil, !timer.canStop {
                Label(
                    "Commitment \(DurationFormatter.hhmmss(timer.remainingCommitment))",
                    systemImage: "lock.fill"
                )
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            Button {
                do {
                    try timer.stop()
                } catch {
                    errors.report(error, while: "Stopping the session")
                }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
                .disabled(!timer.canStop)
        }
    }
}

private struct PendingBrowserClose: Identifiable {
    let id = UUID()
    let activity: Activity
    let minimumDuration: TimeInterval?
    let browsers: [NSRunningApplication]

    var browserNames: String {
        ListFormatter.localizedString(byJoining: browsers.compactMap(\.localizedName))
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case timer
    case activities
    case groups
    case history
    case reports
    case settings

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .timer: "timer"
        case .activities: "list.bullet"
        case .groups: "square.stack.3d.up"
        case .history: "clock.arrow.circlepath"
        case .reports: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}

private struct StartActivitySheet: View {
    let activity: Activity
    let onStart: (TimeInterval?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var choice: CommitmentChoice
    @State private var customMinutes = 30

    init(
        activity: Activity,
        defaultCommitment: CommitmentPreset,
        onStart: @escaping (TimeInterval?) -> Void
    ) {
        self.activity = activity
        self.onStart = onStart
        _choice = State(initialValue: CommitmentChoice(defaultCommitment))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start \(activity.name)")
                .font(.title2.weight(.semibold))

            Picker("Commitment", selection: $choice) {
                ForEach(CommitmentChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            if choice == .custom {
                HStack {
                    Text("Duration")
                    TextField("Minutes", value: $customMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                    Text("minutes")
                        .foregroundStyle(.secondary)
                    Stepper("Minutes", value: $customMinutes, in: 1...480)
                        .labelsHidden()
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Start") { onStart(duration) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var duration: TimeInterval? {
        switch choice {
        case .none: nil
        case .twentyFive: 25 * 60
        case .fifty: 50 * 60
        case .ninety: 90 * 60
        case .custom: TimeInterval(min(max(customMinutes, 1), 480) * 60)
        }
    }
}

private enum CommitmentChoice: String, CaseIterable, Identifiable {
    case none
    case twentyFive
    case fifty
    case ninety
    case custom

    init(_ preset: CommitmentPreset) {
        switch preset {
        case .none: self = .none
        case .twentyFive: self = .twentyFive
        case .fifty: self = .fifty
        case .ninety: self = .ninety
        }
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "None"
        case .twentyFive: "25"
        case .fifty: "50"
        case .ninety: "90"
        case .custom: "Custom"
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
