import Foundation
import UserNotifications

final class NotificationService {
    private var hasRequestedAuthorization = false

    func post(appName: String, activityName: String) {
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "\(appName) is blocked"
        content.body = "\(appName) is blocked while \(activityName) is running"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "timelock.app-blocked.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestAuthorizationIfNeeded() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
