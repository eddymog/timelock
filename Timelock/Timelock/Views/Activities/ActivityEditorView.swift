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

    var body: some View {
        HStack {
            ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
            TextField("Name", text: $activity.name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
            Toggle("Archived", isOn: $activity.isArchived)
                .onChange(of: activity.isArchived) { save() }
        }
        .opacity(activity.isArchived ? 0.5 : 1)
    }

    private func save() {
        errors.perform("Saving the activity") { try context.save() }
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
}
