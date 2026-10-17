import Foundation

/// Where "now" comes from, so view models and formatters can be tested at a fixed moment.
nonisolated protocol Clock: Sendable {
    var now: Date { get }
}

nonisolated struct SystemClock: Clock {
    var now: Date { Date() }
}

nonisolated struct FixedClock: Clock {
    let now: Date

    init(_ now: Date) {
        self.now = now
    }
}
