import Foundation

enum DurationFormatter {
    /// `HH:MM:SS`. Hours keep counting past 24; negatives clamp to zero.
    static func hhmmss(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        return String(format: "%02d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }
}
