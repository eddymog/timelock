import SwiftData
@testable import Timelock

@MainActor
func makeTestContext() throws -> ModelContext {
    let schema = Schema([Activity.self, BlockGroup.self, BlockRule.self, Session.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}
