import Foundation
@testable import Timelock

final class FakeClock: Clock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
