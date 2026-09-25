import Foundation
import SwiftData

enum BlockRuleKind: String, Codable {
    case website
    case app
}

@Model
final class BlockRule {
    var id: UUID = UUID()
    var kind: BlockRuleKind
    /// Normalized domain for websites, bundle identifier for apps.
    var value: String
    var displayName: String

    // Exactly one of these is set.
    var activity: Activity?
    var group: BlockGroup?

    init(kind: BlockRuleKind, value: String, displayName: String) {
        self.kind = kind
        self.value = value
        self.displayName = displayName
    }
}
