import Foundation

/// Activity (MS-133, MS-134): the clinic's open alerts, the member's "seen" marker behind Home's bell dot, and the
/// history of every stock change.
protocol ActivityRepository: Sendable {
    /// `activity_alerts`: the open alerts, newest first, one row per subject.
    func alerts(clinicID: UUID) async throws -> [ActivityAlert]

    /// `alerts_mark_seen`: everything open now counts as seen, so the bell loses its dot.
    func markSeen(clinicID: UUID) async throws

    /// `activity_history`: a page of the ledger, newest first, a procedure's rows one per action unless `productID`
    /// narrows it to one product. `after` is the last entry of the previous page; nil asks for the first.
    func history(
        clinicID: UUID, filter: ActivityHistoryFilter, productID: UUID?, after: ActivityHistoryEntry?, limit: Int
    ) async throws -> [ActivityHistoryEntry]
}
