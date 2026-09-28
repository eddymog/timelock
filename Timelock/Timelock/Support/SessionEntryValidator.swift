import Foundation

enum SessionEntryValidationError: LocalizedError, Equatable {
    case endNotAfterStart
    case endInFuture
    case overlapsRunningSession

    var errorDescription: String? {
        switch self {
        case .endNotAfterStart:
            "End time must be after start time."
        case .endInFuture:
            "Session time cannot be in the future."
        case .overlapsRunningSession:
            "This time overlaps the currently running session."
        }
    }
}

enum SessionEntryValidator {
    static func validate(
        startedAt: Date,
        endedAt: Date,
        now: Date = Date(),
        runningSession: Session?,
        excluding editedSession: Session? = nil
    ) throws {
        guard endedAt > startedAt else {
            throw SessionEntryValidationError.endNotAfterStart
        }
        guard endedAt <= now else {
            throw SessionEntryValidationError.endInFuture
        }
        if let runningSession,
           runningSession.id != editedSession?.id,
           endedAt > runningSession.startedAt {
            throw SessionEntryValidationError.overlapsRunningSession
        }
    }
}
