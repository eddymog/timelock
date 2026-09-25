import Foundation
import SwiftData

@Model
final class BlockGroup {
    var id: UUID = UUID()
    var name: String
    var isGlobal: Bool

    @Relationship(deleteRule: .cascade, inverse: \BlockRule.group)
    var rules: [BlockRule] = []

    var activities: [Activity] = []

    init(name: String, isGlobal: Bool = false) {
        self.name = name
        self.isGlobal = isGlobal
    }
}
