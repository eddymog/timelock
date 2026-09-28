import SwiftData
import SwiftUI

struct GroupEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Query private var groups: [BlockGroup]
    @State private var pendingDelete: BlockGroup?

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                ContentUnavailableView("No Groups", systemImage: "square.stack.3d.up")
            } else {
                List(groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { group in
                    GroupEditorRow(group: group, onDelete: { pendingDelete = group })
                }
            }

            Divider()
            HStack {
                Button(action: addGroup) {
                    Label("Add Group", systemImage: "plus")
                }
                Spacer()
            }
            .padding(10)
        }
        .navigationTitle("Groups")
        .alert(
            "Delete group?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { group in
            Button("Delete", role: .destructive) { delete(group) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { group in
            Text("This deletes \(group.name) and its rules. Past sessions are not affected.")
        }
    }

    private func addGroup() {
        context.insert(BlockGroup(name: "New Group"))
        errors.perform("Adding the group") { try context.save() }
    }

    private func delete(_ group: BlockGroup) {
        pendingDelete = nil
        context.delete(group)
        if !errors.perform("Deleting the group", { try context.save() }) {
            context.rollback()
        }
    }
}

private struct GroupEditorRow: View {
    @Bindable var group: BlockGroup
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: group.isGlobal ? "globe.americas.fill" : "square.stack.3d.up")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                TextField("Name", text: $group.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                Toggle("Global", isOn: $group.isGlobal)
                    .onChange(of: group.isGlobal) { save() }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete group")
                .accessibilityLabel("Delete \(group.name)")
            }

            BlockRuleEditor(
                rules: group.rules,
                ownerName: group.name,
                onAdd: { rule in
                    group.rules.append(rule)
                    save()
                },
                onRemove: { rule in
                    group.rules.removeAll { $0 === rule }
                    context.delete(rule)
                    save()
                }
            )
            .padding(.leading, 26)
        }
        .padding(.vertical, 4)
    }

    private func save() {
        errors.perform("Saving the group") { try context.save() }
    }
}
