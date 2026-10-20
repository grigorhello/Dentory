import Foundation

/// Activity's Alerts (MS-133): the clinic's open alerts and the member's "seen" marker behind Home's bell dot.
protocol ActivityRepository: Sendable {
    /// `activity_alerts`: the open alerts, newest first, one row per subject.
    func alerts(clinicID: UUID) async throws -> [ActivityAlert]

    /// `alerts_mark_seen`: everything open now counts as seen, so the bell loses its dot.
    func markSeen(clinicID: UUID) async throws
}
