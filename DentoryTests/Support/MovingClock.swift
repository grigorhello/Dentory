import Foundation
@testable import Dentory

/// A clock a test moves forward, for durations.
final class MovingClock: Clock, @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}
