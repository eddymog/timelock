import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let blockingCoordinator: BlockingCoordinator
    @State private var launchAtLogin = LaunchAtLoginService()

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .disabled(launchAtLogin.isUpdating)

                if let message = launchAtLogin.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Default Commitment", selection: $settings.defaultCommitment) {
                    ForEach(CommitmentPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Toggle("Notifications", isOn: $settings.notificationsEnabled)
            }

            Section("Website Blocking") {
                HStack {
                    Label(websiteStatusTitle, systemImage: websiteStatusIcon)
                        .foregroundStyle(websiteStatusColor)
                    Spacer()
                    Button {
                        Task { await blockingCoordinator.refreshWebsiteSetupStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh website blocking status")
                    .accessibilityLabel("Refresh website blocking status")
                    .disabled(blockingCoordinator.websiteSetupState == .checking)
                }

                if case .unavailable = blockingCoordinator.websiteSetupState {
                    Text("Run sudo ./Scripts/install.sh from the project folder to enable website blocking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("When Blocking Starts", selection: $settings.browserStartBehavior) {
                    ForEach(BrowserStartBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .navigationTitle("Settings")
        .task {
            launchAtLogin.refresh()
            await blockingCoordinator.refreshWebsiteSetupStatus()
        }
    }

    private var websiteStatusTitle: String {
        switch blockingCoordinator.websiteSetupState {
        case .unknown: "Not Checked"
        case .checking: "Checking"
        case .available(.active): "Installed and Active"
        case .available(.inactive): "Installed"
        case .unavailable: "Unavailable"
        }
    }

    private var websiteStatusIcon: String {
        switch blockingCoordinator.websiteSetupState {
        case .available: "checkmark.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        case .unknown, .checking: "clock"
        }
    }

    private var websiteStatusColor: Color {
        switch blockingCoordinator.websiteSetupState {
        case .available: .green
        case .unavailable: .red
        case .unknown, .checking: .secondary
        }
    }
}
