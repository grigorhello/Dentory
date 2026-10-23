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
    /// Stripe tried to charge it and could not (`payment_failed`): it reads Failed while it stays open.
    var paymentFailed = false
}

nonisolated extension BillingInvoice {
    private enum CodingKeys: String, CodingKey {
        case id, number, issuedAt, amountCents, currency, status, paymentFailed
    }

    /// A cached list from before `payment_failed` existed still reads, as not failed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decodeIfPresent(String.self, forKey: .number)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        amountCents = try container.decode(Int.self, forKey: .amountCents)
        currency = try container.decode(String.self, forKey: .currency)
        status = try container.decode(Status.self, forKey: .status)
        paymentFailed = try container.decodeIfPresent(Bool.self, forKey: .paymentFailed) ?? false
    }
}
