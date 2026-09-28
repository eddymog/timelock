import SwiftData
import SwiftUI

struct HistoryView: View {
    let timer: TimerService
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var editorMode: SessionEditorMode?
    @State private var pendingDelete: Session?

    var body: some View {
        let now = currentTime
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Time")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(DurationFormatter.hhmmss(totalTrackedDuration(for: sessions, at: now)))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Button {
                    editorMode = .add
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
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
                                HistoryRow(
                                    session: session,
                                    now: now,
                                    onEdit: { editorMode = .edit(session) },
                                    onDelete: { pendingDelete = session }
                                )
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
        .sheet(item: $editorMode) { mode in
            SessionEditorSheet(mode: mode, runningSession: timer.runningSession)
        }
        .alert(
            "Delete session?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { session in
            Button("Delete", role: .destructive) { delete(session) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { session in
            Text("This removes the (DurationFormatter.hhmmss(trackedDuration(for: session, at: now))) entry from history.")
        }
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

    private func delete(_ session: Session) {
        guard session.endedAt != nil else { return }
        pendingDelete = nil
        context.delete(session)
        if !errors.perform("Deleting the session", { try context.save() }) {
            context.rollback()
        }
    }
}

private struct HistoryRow: View {
    let session: Session
    let now: Date
    let onEdit: () -> Void
    let onDelete: () -> Void

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
                if !session.note.isEmpty {
                    Text(session.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(DurationFormatter.hhmmss(trackedDuration(for: session, at: now)))
                .monospacedDigit()
            if session.endedAt == nil {
                Text("Running")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit session")
                .accessibilityLabel("Edit session")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete session")
                .accessibilityLabel("Delete session")
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

private enum SessionEditorMode: Identifiable {
    case add
    case edit(Session)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let session): "edit-\(session.id)"
        }
    }

    var session: Session? {
        guard case .edit(let session) = self else { return nil }
        return session
    }
}

private struct SessionEditorSheet: View {
    let mode: SessionEditorMode
    let runningSession: Session?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Activity.createdAt) private var activities: [Activity]
    @State private var selectedActivityID: UUID?
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var note: String
    @State private var formError: String?

    init(mode: SessionEditorMode, runningSession: Session?) {
        self.mode = mode
        self.runningSession = runningSession
        let now = Date()
        let session = mode.session
        _selectedActivityID = State(initialValue: session?.activity?.id)
        _startedAt = State(initialValue: session?.startedAt ?? now.addingTimeInterval(-3_600))
        _endedAt = State(initialValue: session?.endedAt ?? now)
        _note = State(initialValue: session?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode.session == nil ? "Add Entry" : "Edit Session")
                .font(.title2.weight(.semibold))

            Form {
                Picker("Activity", selection: $selectedActivityID) {
                    Text("Choose an activity").tag(nil as UUID?)
                    ForEach(activities) { activity in
                        Text(activity.isArchived ? "\(activity.name) (Archived)" : activity.name)
                            .tag(activity.id as UUID?)
                    }
                }
                DatePicker("Start", selection: $startedAt)
                DatePicker("End", selection: $endedAt)
                TextField("Note (optional)", text: $note)
            }
            .formStyle(.grouped)

            if let formError {
                Label(formError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedActivityID == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if selectedActivityID == nil {
                selectedActivityID = activities.first(where: { !$0.isArchived })?.id ?? activities.first?.id
            }
        }
    }

    private func save() {
        guard let activity = activities.first(where: { $0.id == selectedActivityID }) else {
            formError = "Choose an activity."
            return
        }

        do {
            try SessionEntryValidator.validate(
                startedAt: startedAt,
                endedAt: endedAt,
                runningSession: runningSession,
                excluding: mode.session
            )

            if let session = mode.session {
                let previous = (session.activity, session.startedAt, session.endedAt, session.note)
                session.activity = activity
                session.startedAt = startedAt
                session.endedAt = endedAt
                session.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                do {
                    try context.save()
                } catch {
                    (session.activity, session.startedAt, session.endedAt, session.note) = previous
                    throw error
                }
            } else {
                let session = Session(startedAt: startedAt)
                session.activity = activity
                session.endedAt = endedAt
                session.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                context.insert(session)
                do {
                    try context.save()
                } catch {
                    context.delete(session)
                    throw error
                }
            }
            dismiss()
        } catch {
            formError = error.localizedDescription
        }
    }
}
