import AppKit
import SwiftUI
import SwiftData

/// Minimal activity manager: add, rename, recolor, archive (FR-101, FR-102).
struct ActivityEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Query(sort: \Activity.createdAt) private var activities: [Activity]

    var body: some View {
        VStack(spacing: 0) {
            List(activities) { activity in
                ActivityEditorRow(activity: activity)
            }
            Divider()
            HStack {
                Button {
                    context.insert(Activity(name: "New Activity", colorHex: "#3B82F6"))
                    errors.perform("Adding the activity") { try context.save() }
                } label: {
                    Label("Add Activity", systemImage: "plus")
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(minWidth: 420, minHeight: 320)
        .errorAlert(errors)
    }
}

private struct ActivityEditorRow: View {
    @Bindable var activity: Activity
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Query private var groups: [BlockGroup]
    @State private var groupsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                TextField("Name", text: $activity.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                Toggle("Archived", isOn: $activity.isArchived)
                    .onChange(of: activity.isArchived) { save() }
            }

            BlockRuleEditor(
                rules: activity.rules,
                ownerName: activity.name,
                onAdd: { rule in
                    activity.rules.append(rule)
                    save()
                },
                onRemove: remove
            )

            ruleSection("Groups", isExpanded: $groupsExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { group in
                        if group.isGlobal {
                            HStack {
                                Image(systemName: "globe.americas.fill")
                                    .foregroundStyle(.secondary)
                                Text(group.name)
                                Spacer()
                                Text("Global")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Toggle(group.name, isOn: groupBinding(group))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
        .opacity(activity.isArchived ? 0.5 : 1)
    }

    private func save() {
        errors.perform("Saving the activity") { try context.save() }
    }

    private func ruleSection<Content: View>(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 12)
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(isExpanded.wrappedValue ? "expanded" : "collapsed")")

            if isExpanded.wrappedValue {
                content()
                    .padding(.leading, 18)
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: activity.colorHex) },
            set: { newColor in
                guard let c = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                activity.colorHex = HexColor.hex(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
                save()
            }
        )
    }

    private func remove(_ rule: BlockRule) {
        activity.rules.removeAll { $0 === rule }
        context.delete(rule)
        save()
    }

    private func groupBinding(_ group: BlockGroup) -> Binding<Bool> {
        Binding(
            get: { activity.groups.contains { $0.id == group.id } },
            set: { isAttached in
                if isAttached {
                    guard !activity.groups.contains(where: { $0.id == group.id }) else { return }
                    activity.groups.append(group)
                } else {
                    activity.groups.removeAll { $0.id == group.id }
                }
                save()
            }
        )
    }
}
