import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var websiteInput = ""
    @State private var websiteError: String?
    @State private var websitesExpanded = false
    @State private var appsExpanded = false

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

            ruleSection("Websites", isExpanded: $websitesExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(activity.rules.filter { $0.kind == .website }) { rule in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.secondary)
                            Text(rule.value)
                            Spacer()
                            Button {
                                remove(rule)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(rule.value)")
                        }
                    }

                    HStack {
                        TextField("Domain or URL", text: $websiteInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addWebsiteRule() }
                        Button {
                            addWebsiteRule()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Add website")
                    }
                    if let websiteError {
                        Text(websiteError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.leading, 4)
            }

            ruleSection("Apps", isExpanded: $appsExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(activity.rules.filter { $0.kind == .app }) { rule in
                        HStack {
                            Image(systemName: "app")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rule.displayName)
                                Text(rule.value)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                remove(rule)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(rule.displayName)")
                        }
                    }

                    Button {
                        addAppRule()
                    } label: {
                        Label("Add App", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
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

    private func addAppRule() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.message = "Choose an app to block while this activity is running."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            errors.report(ActivityEditorError.invalidAppBundle, while: "Adding the app rule")
            return
        }

        if activity.rules.contains(where: { $0.kind == .app && $0.value == bundleID }) {
            return
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        activity.rules.append(BlockRule(kind: .app, value: bundleID, displayName: displayName))
        save()
    }

    private func addWebsiteRule() {
        guard let domain = DomainNormalizer.normalize(websiteInput) else {
            websiteError = "Enter a valid domain or HTTP(S) URL."
            return
        }
        websiteError = nil
        websiteInput = ""
        guard !activity.rules.contains(where: { $0.kind == .website && $0.value == domain }) else { return }

        activity.rules.append(BlockRule(kind: .website, value: domain, displayName: domain))
        save()
    }

    private func remove(_ rule: BlockRule) {
        activity.rules.removeAll { $0 === rule }
        context.delete(rule)
        save()
    }
}

private enum ActivityEditorError: LocalizedError {
    case invalidAppBundle

    var errorDescription: String? {
        switch self {
        case .invalidAppBundle:
            "The selected app does not have a bundle identifier."
        }
    }
}
