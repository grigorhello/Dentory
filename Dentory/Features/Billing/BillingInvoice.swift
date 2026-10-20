import Foundation

/// One of the clinic's Stripe invoices as `billing_invoices` keeps it (MS-140, MS-141): its date, amount and status,
/// without links (MS-100 D18: Stripe emails the invoices and receipts).
nonisolated struct BillingInvoice: Codable, Equatable, Identifiable, Sendable {
    /// Stripe's invoice statuses; a void one was cancelled, an uncollectible one could not be charged.
    enum Status: String, Codable, Sendable {
        case draft, open, paid, void, uncollectible
    }

    let id: UUID
    let number: String?
    let issuedAt: Date
    let amountCents: Int
    /// Lowercase ISO 4217, as Stripe gives it: "usd".
    let currency: String
    let status: Status
}
