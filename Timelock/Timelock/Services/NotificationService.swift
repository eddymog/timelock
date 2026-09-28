import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private let isEnabled: () -> Bool
    private let now: () -> Date
    private var hasRequestedAuthorization = false
    private var throttle = NotificationThrottle(cooldown: 10)

    init(isEnabled: @escaping () -> Bool = { true }, now: @escaping () -> Date = Date.init) {
        self.isEnabled = isEnabled
        self.now = now
    }

    func post(appName: String, activityName: String) {
        guard isEnabled() else { return }
        guard throttle.shouldPost(key: "\(activityName)|\(appName)", at: now()) else { return }
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

struct NotificationThrottle {
    let cooldown: TimeInterval
    private var lastPostedAt: [String: Date] = [:]

    mutating func shouldPost(key: String, at now: Date) -> Bool {
        if let lastPostedAt = lastPostedAt[key],
           now >= lastPostedAt,
           now.timeIntervalSince(lastPostedAt) < cooldown {
            return false
        }
        lastPostedAt[key] = now
        return true
    }
}
