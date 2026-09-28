import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BlockRuleEditor: View {
    let rules: [BlockRule]
    let ownerName: String
    let onAdd: (BlockRule) -> Void
    let onRemove: (BlockRule) -> Void

    @Environment(ErrorCenter.self) private var errors
    @State private var websiteInput = ""
    @State private var websiteError: String?
    @State private var websitesExpanded = false
    @State private var appsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ruleSection("Websites", isExpanded: $websitesExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rules.filter { $0.kind == .website }) { rule in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.secondary)
                            Text(rule.value)
                            Spacer()
                            removeButton(rule)
                        }
                    }

                    HStack {
                        TextField("Domain or URL", text: $websiteInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addWebsiteRule() }
                        Button(action: addWebsiteRule) {
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
                    ForEach(rules.filter { $0.kind == .app }) { rule in
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
                            removeButton(rule)
                        }
                    }

                    Button(action: addAppRule) {
                        Label("Add App", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.leading, 4)
            }
        }
    }

    private func removeButton(_ rule: BlockRule) -> some View {
        Button {
            onRemove(rule)
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove \(rule.displayName)")
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

    private func addAppRule() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.message = "Choose an app for \(ownerName)."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            errors.report(BlockRuleEditorError.invalidAppBundle, while: "Adding the app rule")
            return
        }
        guard !rules.contains(where: { $0.kind == .app && $0.value == bundleID }) else { return }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        onAdd(BlockRule(kind: .app, value: bundleID, displayName: displayName))
    }

    private func addWebsiteRule() {
        guard let domain = DomainNormalizer.normalize(websiteInput) else {
            websiteError = "Enter a valid domain or HTTP(S) URL."
            return
        }
        websiteError = nil
        websiteInput = ""
        guard !rules.contains(where: { $0.kind == .website && $0.value == domain }) else { return }
        onAdd(BlockRule(kind: .website, value: domain, displayName: domain))
    }
}

private enum BlockRuleEditorError: LocalizedError {
    case invalidAppBundle

    var errorDescription: String? {
        "The selected app does not have a bundle identifier."
    }
}
