import Foundation

/// One past procedure in the Procedures tab's history (f11): what was done, when, by whom and how many supplies it
/// recorded, as `procedure_history` reports it. Cancelled procedures stay in the history with their date.
nonisolated struct ProcedureEventSummary: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let startedAt: Date
    /// The member's full name ("Sarah Mitchell"); empty when the membership is gone.
    let startedByName: String
    let itemCount: Int
    let cancelledAt: Date?
}
