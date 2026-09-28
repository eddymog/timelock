import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class LaunchAtLoginService {
    private(set) var isEnabled = false
    private(set) var isUpdating = false
    private(set) var statusMessage: String?

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        isUpdating = true
        statusMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
        isUpdating = false
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        if status == .requiresApproval {
            statusMessage = "Approval is required in System Settings."
        }
    }
}
