import XCTest
import SwiftData
@testable import Timelock

@MainActor
final class ActivitySeederTests: XCTestCase {

    func testSeedsWorkingOnEmptyStore() throws {
        let context = try makeTestContext()

        try ActivitySeeder.seedIfEmpty(context)

        let activities = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(activities.map(\.name), ["Working"])
    }

    func testDoesNotSeedWhenActivitiesExist() throws {
        let context = try makeTestContext()
        context.insert(Activity(name: "Reading", colorHex: "#00FF00"))
        try context.save()

        try ActivitySeeder.seedIfEmpty(context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Activity>()), 1)
    }

    func testDoesNotReseedWhenAllActivitiesAreArchived() throws {
        let context = try makeTestContext()
        let archived = Activity(name: "Old", colorHex: "#00FF00")
        archived.isArchived = true
        context.insert(archived)
        try context.save()

        try ActivitySeeder.seedIfEmpty(context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Activity>()), 1)
    }
}
