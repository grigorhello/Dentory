import Foundation

/// Screens Receive delivery pushes on the stack it is on (Home's or Inventory's).
enum ReceiveRoute: Hashable {
    /// Review invoice for an invoice being read or ready to review (MS-129, MS-130), or the failure with Try again and
    /// Receive manually for one whose reading failed.
    case invoice(UUID)
    /// Review invoice for pages just captured: it uploads them, creates the invoice and follows its reading (MS-129).
    case newInvoice(InvoiceDocument)
    /// Receive manually (MS-127), with the product already chosen when the route names one (Appendix B `productId`).
    case manual(productID: UUID? = nil)
}
