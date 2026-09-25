import SwiftData

enum ActivitySeeder {
    /// Creates the starter "Working" activity when the store has no activities at all.
    static func seedIfEmpty(_ context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Activity>()) == 0 else { return }
        context.insert(Activity(name: "Working", colorHex: "#3B82F6"))
        try context.save()
    }
}
