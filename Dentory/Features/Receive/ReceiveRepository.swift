import Foundation

/// Receive delivery (MS-126): what the screen lists under its options. Admin only; the server refuses anyone else.
protocol ReceiveRepository: Sendable {
    /// `receive_overview`: the invoices still being read or ready to review, and the lines marked Ordered.
    func overview(clinicID: UUID) async throws -> ReceiveOverview
}
