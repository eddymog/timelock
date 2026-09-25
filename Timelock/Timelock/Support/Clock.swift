import Foundation

/// Source of the current time, injected so timer logic can be tested.
protocol Clock: AnyObject {
    var now: Date { get }
}

final class SystemClock: Clock {
    var now: Date { Date() }
}
