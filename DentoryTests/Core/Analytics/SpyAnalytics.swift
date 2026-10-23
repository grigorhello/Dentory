import Foundation
@testable import Dentory

/// Records what a view model sends to analytics.
final class SpyAnalytics: Analytics, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var identified: [Session] = []
    private(set) var resetCount = 0
    /// Identify and reset in the order they came: "identify <user id>", "reset".
    private(set) var log: [String] = []

    func start() {}

    func identify(_ session: Session) {
        identified.append(session)
        log.append("identify \(session.userID)")
    }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func reset() {
        resetCount += 1
        log.append("reset")
    }
}
