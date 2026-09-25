import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID = UUID()
    var activity: Activity?
    var startedAt: Date
    /// nil while the session is running.
    var endedAt: Date?
    var note: String = ""
    /// nil = Gentle; set = Commitment (Stop disabled until then).
    var minimumEndAt: Date?

    init(startedAt: Date, minimumEndAt: Date? = nil) {
        self.startedAt = startedAt
        self.minimumEndAt = minimumEndAt
    }
}
