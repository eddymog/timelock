import Foundation
import SwiftData

@Model
final class Activity {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var createdAt: Date
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \BlockRule.activity)
    var rules: [BlockRule] = []

    @Relationship(inverse: \BlockGroup.activities)
    var groups: [BlockGroup] = []

    @Relationship(deleteRule: .cascade, inverse: \Session.activity)
    var sessions: [Session] = []

    init(name: String, colorHex: String, createdAt: Date = Date()) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
