import Foundation
@testable import Dentory

/// Records what a view model sends to analytics.
final class SpyAnalytics: Analytics, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var identified: [Session] = []
    private(set) var resetCount = 0

    func start() {}

    func identify(_ session: Session) {
        identified.append(session)
    }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func reset() {
        resetCount += 1
    }
}
