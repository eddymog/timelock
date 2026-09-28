import AppKit
import Foundation

@MainActor
final class AppBlocker: AppBlocking {
    private let notificationService: NotificationService
    private var blockedBundleIDs = Set<String>()
    private var activityName = ""
    private var launchObserver: NSObjectProtocol?

    init() {
        self.notificationService = NotificationService()
    }

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    func start(bundleIDs: [String], activityName: String) {
        stop()
        blockedBundleIDs = Set(bundleIDs).subtracting([Bundle.main.bundleIdentifier].compactMap { $0 })
        self.activityName = activityName

        for bundleID in blockedBundleIDs {
            terminateRunningApplications(with: bundleID)
        }

        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let blocker = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else {
                return
            }
            Task { @MainActor in
                blocker.handleLaunch(app)
            }
        }
    }

    func stop() {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
        blockedBundleIDs.removeAll()
        activityName = ""
    }

    private func handleLaunch(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier, blockedBundleIDs.contains(bundleID) else { return }
        terminate(app)
        notificationService.post(appName: app.localizedName ?? bundleID, activityName: activityName)
    }

    private func terminateRunningApplications(with bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            terminate(app)
            notificationService.post(appName: app.localizedName ?? bundleID, activityName: activityName)
        }
    }

    private func terminate(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        app.terminate()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !app.isTerminated {
                app.forceTerminate()
            }
        }
    }
}
