import Foundation

/// Reads what Account shows beyond the session (MS-137) and starts the admin's CSV export (MS-143).
protocol AccountRepository: Sendable {
    /// The clinic's active members, "3 people" on the Team row; pending invitations are left out.
    func teamSize(clinicID: UUID) async throws -> Int

    /// Asks the server for the clinic's export: products, batches and transactions as CSV files in a zip, emailed to
    /// the admin with a link valid 7 days. Answers the address the link goes to.
    func startExport(clinicID: UUID) async throws -> String
}
