import Foundation

/// Screens Receive delivery pushes on the stack it is on (Home's or Inventory's). Each arrives with its own ticket;
/// until then the destination is a placeholder pushed screen.
enum ReceiveRoute: Hashable {
    /// Review invoice for an invoice being read or ready to review (MS-129, MS-130).
    case invoice(UUID)
    /// Review invoice in reading state for pages just captured: MS-129 uploads them and replaces this with `invoice`.
    case newInvoice(source: InvoiceDocument.Source, pageCount: Int)
    /// Receive manually (MS-127).
    case manual
}
