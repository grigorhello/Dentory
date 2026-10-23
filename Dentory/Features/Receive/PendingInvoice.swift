import Foundation

/// An invoice the admin can go back to (PRD §6.5): uploaded and still being read, or read and waiting for review.
/// Confirmed, failed and discarded invoices are not listed.
nonisolated struct PendingInvoice: Codable, Equatable, Identifiable, Sendable {
    nonisolated enum Status: String, Codable, Sendable {
        case reading
        case ready
    }

    let id: UUID
    let status: Status
    /// Known once the invoice is read.
    let supplier: String?
    /// When it was uploaded.
    let createdAt: Date
}
