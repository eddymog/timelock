import XCTest
import SwiftData
@testable import Timelock

@MainActor
final class BlockingCoordinatorTests: XCTestCase {
    func testEffectiveRulesMergesActivityGroupsAndGlobalsInOrder() {
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        let attached = BlockGroup(name: "Distractions")
        let global = BlockGroup(name: "Always", isGlobal: true)
        let activityRule = BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord")
        let groupRule = BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube")
        let globalRule = BlockRule(kind: .app, value: "com.apple.Music", displayName: "Music")
        activity.rules.append(activityRule)
        attached.rules.append(groupRule)
        global.rules.append(globalRule)
        activity.groups.append(attached)

        let rules = effectiveRules(for: activity, globalGroups: [global])

        XCTAssertEqual(rules.map(\.value), ["com.hnc.Discord", "youtube.com", "com.apple.Music"])
    }

    func testEffectiveRulesRemovesDuplicatesByKindAndValue() {
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        let group = BlockGroup(name: "Distractions")
        let global = BlockGroup(name: "Always", isGlobal: true)
        activity.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord"))
        group.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord copy"))
        global.rules.append(BlockRule(kind: .website, value: "discord.com", displayName: "Discord Web"))
        activity.groups.append(group)

        let rules = effectiveRules(for: activity, globalGroups: [global])

        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules.map(\.displayName), ["Discord", "Discord Web"])
    }

    func testApplyStartsAppBlockerWithOnlyAppRules() {
        let fake = FakeAppBlocker()
        let coordinator = BlockingCoordinator(appBlocker: fake)
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        activity.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord"))
        activity.rules.append(BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube"))

        coordinator.apply(activity: activity, globalGroups: [])

        XCTAssertEqual(fake.startedBundleIDs, ["com.hnc.Discord"])
        XCTAssertEqual(fake.activityName, "Working")
    }

    func testClearStopsAppBlocker() {
        let fake = FakeAppBlocker()
        let coordinator = BlockingCoordinator(appBlocker: fake)

        coordinator.clear()

        XCTAssertTrue(fake.didStop)
    }

    func testApplyBlocksExpandedWebsiteDomains() async {
        let appBlocker = FakeAppBlocker()
        let websiteBlocker = FakeWebsiteBlocker()
        let coordinator = BlockingCoordinator(appBlocker: appBlocker, websiteBlocker: websiteBlocker)
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        activity.rules.append(BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube"))

        coordinator.apply(activity: activity, globalGroups: [])
        await coordinator.waitForPendingWebsiteOperations()

        XCTAssertEqual(websiteBlocker.calls, [.block(["youtube.com", "www.youtube.com"])])
        XCTAssertNil(coordinator.websiteWarning)
    }

    func testApplyFailureKeepsAppBlockingActiveAndShowsWarning() async {
        let appBlocker = FakeAppBlocker()
        let websiteBlocker = FakeWebsiteBlocker()
        websiteBlocker.error = TestWebsiteError.failed
        let coordinator = BlockingCoordinator(appBlocker: appBlocker, websiteBlocker: websiteBlocker)
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        activity.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord"))
        activity.rules.append(BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube"))

        coordinator.apply(activity: activity, globalGroups: [])
        await coordinator.waitForPendingWebsiteOperations()

        XCTAssertEqual(appBlocker.startedBundleIDs, ["com.hnc.Discord"])
        XCTAssertEqual(coordinator.websiteWarning, "Website blocking unavailable – run install.sh")
    }

    func testClearUnblocksWebsites() async {
        let websiteBlocker = FakeWebsiteBlocker()
        let coordinator = BlockingCoordinator(appBlocker: FakeAppBlocker(), websiteBlocker: websiteBlocker)

        coordinator.clear()
        await coordinator.waitForPendingWebsiteOperations()

        XCTAssertEqual(websiteBlocker.calls, [.unblock])
    }

    func testIdleLaunchChecksStatusThenClearsStaleBlock() async {
        let websiteBlocker = FakeWebsiteBlocker()
        let coordinator = BlockingCoordinator(appBlocker: FakeAppBlocker(), websiteBlocker: websiteBlocker)

        coordinator.prepareForIdleLaunch()
        await coordinator.waitForPendingWebsiteOperations()

        XCTAssertEqual(websiteBlocker.calls, [.status, .unblock])
    }

    func testRefreshWebsiteSetupStatusReportsAvailability() async {
        let websiteBlocker = FakeWebsiteBlocker()
        let coordinator = BlockingCoordinator(
            appBlocker: FakeAppBlocker(),
            websiteBlocker: websiteBlocker
        )

        await coordinator.refreshWebsiteSetupStatus()

        XCTAssertEqual(coordinator.websiteSetupState, .available(.inactive))
        XCTAssertEqual(websiteBlocker.calls, [.status])
    }

    func testRefreshWebsiteSetupStatusReportsFailure() async {
        let websiteBlocker = FakeWebsiteBlocker()
        websiteBlocker.error = TestWebsiteError.failed
        let coordinator = BlockingCoordinator(
            appBlocker: FakeAppBlocker(),
            websiteBlocker: websiteBlocker
        )

        await coordinator.refreshWebsiteSetupStatus()

        guard case .unavailable = coordinator.websiteSetupState else {
            return XCTFail("Expected unavailable setup state")
        }
    }
}

private final class FakeAppBlocker: AppBlocking {
    private(set) var startedBundleIDs: [String] = []
    private(set) var activityName: String?
    private(set) var didStop = false

    func start(bundleIDs: [String], activityName: String) {
        startedBundleIDs = bundleIDs
        self.activityName = activityName
    }

    func stop() {
        didStop = true
    }
}

private enum WebsiteCall: Equatable {
    case block([String])
    case unblock
    case status
}

private enum TestWebsiteError: Error {
    case failed
}

private final class FakeWebsiteBlocker: WebsiteBlocking {
    var error: Error?
    private(set) var calls: [WebsiteCall] = []

    func block(_ domains: [String]) async throws {
        calls.append(.block(domains))
        if let error { throw error }
    }

    func unblock() async throws {
        calls.append(.unblock)
        if let error { throw error }
    }

    func status() async throws -> WebsiteBlockerStatus {
        calls.append(.status)
        if let error { throw error }
        return .inactive
    }
}
