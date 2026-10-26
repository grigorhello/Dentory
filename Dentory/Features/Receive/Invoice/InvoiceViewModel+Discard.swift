import Foundation

/// Discard invoice (the ticket: the header's "…" menu, then a confirmation): an invoice waiting for review, or whose
/// reading failed, is set aside and its photo or file deleted. The discard itself is in `InvoiceViewModel.swift`.
extension InvoiceViewModel {
    /// The menu shows once the invoice exists and is neither received nor set aside.
    var canDiscard: Bool { state == .ready || state == .failed }

    var isDiscarding: Bool { discardGuard.isBusy }

    /// Discard invoice in the menu: the question before anything is deleted.
    func askToDiscard() {
        isConfirmingDiscard = true
    }

    func keepInvoice() {
        isConfirmingDiscard = false
    }
}
