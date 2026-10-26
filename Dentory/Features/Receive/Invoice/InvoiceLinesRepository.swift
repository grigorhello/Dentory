import Foundation

/// Review invoice's lines (MS-130, Appendix B `invoice.line[n]`): each choice is saved on the server as it is made, so
/// the admin can leave and come back, and answers the line as it now stands. The server refuses a line already
/// resolved, a product that was deleted and an invoice no longer waiting for review, besides anyone but an admin and a
/// read-only clinic.
protocol InvoiceLinesRepository: Sendable {
    /// `invoice_line_match`: Yes, match, or a product picked on Which product is this? The line is Matched.
    func matchLine(_ lineID: UUID, to productID: UUID) async throws -> InvoiceLine
    /// `invoice_line_create`: Create and use for this line. The line is Created as the product just created.
    func createLine(_ lineID: UUID, as productID: UUID) async throws -> InvoiceLine
    /// `invoice_line_skip`: Ignore on a fee. The line is Skipped.
    func skipLine(_ lineID: UUID) async throws -> InvoiceLine
    /// `invoice_line_reopen`: the badge of a resolved line, or Undo on a skipped one; back to the state it was read in.
    func reopenLine(_ lineID: UUID) async throws -> InvoiceLine
    /// `invoice_line_batch`: the Lot and Expiry inputs; nil clears them.
    func setBatch(of lineID: UUID, lot: String?, expiryMonth: CalendarDay?) async throws -> InvoiceLine
}
