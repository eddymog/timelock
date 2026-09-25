import SwiftUI
import SwiftData

/// Minimal activity manager: add, rename, recolor, archive (FR-101, FR-102).
struct ActivityEditorView: View {
    @Environment(\.modelContext) private var context
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
                    try? context.save()
                } label: {
                    Label("Add Activity", systemImage: "plus")
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

private struct ActivityEditorRow: View {
    @Bindable var activity: Activity
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack {
            ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
            TextField("Name", text: $activity.name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { try? context.save() }
            Toggle("Archived", isOn: $activity.isArchived)
                .onChange(of: activity.isArchived) { try? context.save() }
        }
        .opacity(activity.isArchived ? 0.5 : 1)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: activity.colorHex) },
            set: { newColor in
                guard let c = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                activity.colorHex = HexColor.hex(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
                try? context.save()
            }
        )
    }
}
