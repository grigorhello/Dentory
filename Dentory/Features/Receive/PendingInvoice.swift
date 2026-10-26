import Foundation

/// An invoice the admin can go back to (PRD §6.5): uploaded and still being read, read and waiting for review, or one
/// whose reading failed, which opens the failure with Try again and Receive manually (the MS-129 fix). Confirmed and
/// discarded invoices are not listed.
nonisolated struct PendingInvoice: Codable, Equatable, Identifiable, Sendable {
    nonisolated enum Status: String, Codable, Sendable {
        case reading
        case ready
        case failed
    }

    let id: UUID
    let status: Status
    /// Known once the invoice is read.
    let supplier: String?
    /// When it was uploaded.
    let createdAt: Date
    /// When its reading failed; only for a failed invoice.
    var failedAt: Date?
}
