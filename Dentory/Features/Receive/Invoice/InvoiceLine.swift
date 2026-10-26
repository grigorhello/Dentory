import Foundation

/// One line of an invoice as Review invoice shows it (f23; PRD §6.5; Appendix B `invoice.line[n]`), as
/// `invoice_detail` and the line functions answer it: what was read, the state the line is in and the state it was
/// read in, the product it became, the product a Possible match suggests, what New product starts from, and the lot
/// and expiry month. Decoded with the client's decoder (`JSONDecoder.supabase`, snake_case keys).
nonisolated struct InvoiceLine: Codable, Equatable, Identifiable, Sendable {
    /// PRD §7's invoice line states.
    nonisolated enum State: String, Codable, Sendable {
        case matched
        case possibleMatch = "possible_match"
        case newProduct = "new_product"
        case needsReview = "needs_review"
        case created
        case skipped
    }

    /// What the reader called the line: a product, or a fee, surcharge, shipping, tax, discount or credit.
    nonisolated enum Kind: String, Codable, Sendable {
        case product, fee
    }

    let id: UUID
    /// The line's place on the invoice, from 1: the `n` of `invoice.line[n]`.
    let number: Int
    /// The line as written on the invoice.
    let raw: String
    let qty: Decimal?
    /// What the quantity counts, as read ("box"); nil for a fee.
    let unit: String?
    let unitPrice: Decimal?
    let lineTotal: Decimal?
    let kind: Kind
    let state: State
    /// The state the reading gave the line; the admin's choices never change it (MS-147's matched share).
    let readState: State
    /// The product a Matched or Created line is.
    let productID: UUID?
    let productName: String?
    /// The product a Possible match asks about.
    let suggestedProductID: UUID?
    let suggestedProductName: String?
    /// What New product starts from: a name and a counted-in unit suggested from the line.
    let suggestedName: String?
    let suggestedUnit: String?
    var lot: String?
    var expiryMonth: CalendarDay?

    /// Settled: Matched, Created or Skipped. Confirm & receive waits for every line to be (MS-131).
    var isResolved: Bool {
        switch state {
        case .matched, .created, .skipped: true
        case .possibleMatch, .newProduct, .needsReview: false
        }
    }

    /// Matched and Created lines go into stock, with a lot and an expiry month.
    var increasesInventory: Bool { state == .matched || state == .created }

    /// What Confirm & receive puts into stock (MS-131): a Matched or Created line with a quantity above 0; one whose
    /// quantity the reading could not tell, or a credit, adds nothing.
    var receivesStock: Bool { increasesInventory && (qty ?? 0) > 0 }

    /// The admin settled it: its badge (or Undo) takes it back to the state it was read in. A line read as Matched
    /// is already in that state.
    var canReopen: Bool { isResolved && state != readState }

    private enum CodingKeys: String, CodingKey {
        case id, number = "n", raw, qty, unit, unitPrice, lineTotal, kind, state, readState
        case productID = "productId", productName, suggestedProductID = "suggestedProductId", suggestedProductName
        case suggestedName, suggestedUnit, lot, expiryMonth
    }
}
