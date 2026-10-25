import Foundation

/// Screens Receive delivery pushes on the stack it is on (Home's or Inventory's). Review invoice arrives with its own
/// tickets; until then its destination is a placeholder pushed screen.
enum ReceiveRoute: Hashable {
    /// Review invoice for an invoice being read or ready to review (MS-129, MS-130).
    case invoice(UUID)
    /// Review invoice in reading state for pages just captured: MS-129 uploads them and replaces this with `invoice`.
    case newInvoice(source: InvoiceDocument.Source, pageCount: Int)
    /// Receive manually (MS-127), with the product already chosen when the route names one (Appendix B `productId`).
    case manual(productID: UUID? = nil)
}
