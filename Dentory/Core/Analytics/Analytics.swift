import Foundation

/// Product analytics (MS-147): what the clinics do with the app, for the pilot's metrics. Events are named by the PRD
/// Appendix B element id the person used (MS-100 D3) and carry counts, seconds and words from closed lists only
/// (`AnalyticsEvent`). The user goes by their id, their role and their clinic's id: never a name, an email, text
/// someone typed or an invoice's contents.
protocol Analytics: Sendable {
    func start()
    /// The signed-in member, after sign-in, sign-up, joining or a restored session.
    func identify(_ session: Session)
    func track(_ event: AnalyticsEvent)
    /// Sign out: what follows belongs to nobody until the next sign-in.
    func reset()
}

/// Sends nothing; for previews, tests and builds without a project key.
struct NoopAnalytics: Analytics {
    func start() {}
    func identify(_ session: Session) {}
    func track(_ event: AnalyticsEvent) {}
    func reset() {}
}
