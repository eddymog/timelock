import XCTest
@testable import Timelock

@MainActor
final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsAreGentleAskAndNotificationsEnabled() {
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.defaultCommitment, .none)
        XCTAssertEqual(settings.browserStartBehavior, .ask)
        XCTAssertTrue(settings.notificationsEnabled)
    }

    func testChangesPersist() {
        let settings = AppSettings(defaults: defaults)
        settings.defaultCommitment = .fifty
        settings.browserStartBehavior = .close
        settings.notificationsEnabled = false

        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.defaultCommitment, .fifty)
        XCTAssertEqual(restored.browserStartBehavior, .close)
        XCTAssertFalse(restored.notificationsEnabled)
    }
}
