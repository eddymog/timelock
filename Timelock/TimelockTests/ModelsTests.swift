import XCTest
import SwiftData
@testable import Timelock

@MainActor
final class ModelsTests: XCTestCase {

    func testActivityPersistsWithRulesGroupsAndSessions() throws {
        let context = try makeTestContext()
        let activity = Activity(name: "Working", colorHex: "#FF0000", createdAt: Date(timeIntervalSince1970: 0))
        let group = BlockGroup(name: "Distractions", isGlobal: false)
        context.insert(activity)
        context.insert(group)
        activity.rules.append(BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube"))
        group.rules.append(BlockRule(kind: .app, value: "com.hnc.Discord", displayName: "Discord"))
        activity.groups.append(group)
        activity.sessions.append(Session(startedAt: Date(timeIntervalSince1970: 100)))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].rules.first?.kind, .website)
        XCTAssertEqual(fetched[0].groups.first?.rules.first?.value, "com.hnc.Discord")
        XCTAssertNil(fetched[0].sessions.first?.endedAt)
        XCTAssertFalse(fetched[0].isArchived)
    }

    func testDeletingActivityCascadesToItsRules() throws {
        let context = try makeTestContext()
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        context.insert(activity)
        activity.rules.append(BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube"))
        try context.save()

        context.delete(activity)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BlockRule>()), 0)
    }

    func testDeletingGroupCascadesRulesAndDetachesActivity() throws {
        let context = try makeTestContext()
        let activity = Activity(name: "Working", colorHex: "#FF0000")
        let group = BlockGroup(name: "Distractions")
        context.insert(activity)
        context.insert(group)
        group.rules.append(BlockRule(kind: .website, value: "youtube.com", displayName: "YouTube"))
        activity.groups.append(group)
        try context.save()

        context.delete(group)
        try context.save()

        XCTAssertTrue(activity.groups.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BlockRule>()), 0)
    }
}
