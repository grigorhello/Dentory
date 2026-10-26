import Foundation

/// What Review invoice says around its lines (f23, PRD §6.5 and §7, Appendix B `invoice`, the ticket's failure notice
/// and Discard invoice); the lines' own words are in `InvoiceReviewViewModel+Copy.swift`. The state and the intents are
/// in `InvoiceViewModel.swift`.
extension InvoiceViewModel {
    static let title = "Review invoice"
    static let readingTitle = "Reading invoice"
    static let readingCaption = "Usually under 20 seconds."
    static let receiveManuallyInstead = "Receive manually instead"
    static let readingFailure = "We couldn't read this invoice. Try a clearer photo or receive manually."
    static let uploadFailure = "Couldn't upload the invoice. Check the connection and try again."
    static let loadFailure = "Couldn't open this invoice. Check the connection and try again."
    static let closed = "This invoice is no longer waiting for review."
    static let tryAgain = "Try again"
    static let receiveManually = "Receive manually"
    /// The header's "…" menu and Discard invoice (PRD §7: one sentence of what happens, the danger button, Keep).
    static let menuLabel = "More"
    static let discardTitle = "Discard invoice"
    static let discardQuestion = "Discard this invoice?"
    static let discardMessage = "Nothing is added to inventory, and the invoice's photo or file is deleted."
    static let keepTitle = "Keep"
    static let discardedTitle = "Invoice discarded"

    /// The header once read (`invoice.header`): "Patterson Dental · INV-10092 · $449.00", in the invoice's own currency
    /// when it names one; a part the invoice does not show is left out.
    var header: String? {
        guard let invoice, state == .ready || state == .closed else { return nil }
        let total = invoice.total.map { formatters(for: invoice).money($0) }
        let parts = [invoice.supplier, invoice.number, total].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Money in the invoice's own currency when it names one, else the clinic's: the header and the lines' prices.
    func formatters(for invoice: InvoiceSummary) -> ClinicFormatters {
        ClinicFormatters(
            currency: invoice.currency ?? formatters.currency, timeZone: formatters.timeZone,
            locale: formatters.locale, clock: formatters.clock
        )
    }

    /// "AI read 4 lines. Check each one, then confirm." (`invoice.banner`).
    var banner: String? {
        guard let invoice, state == .ready else { return nil }
        let lines = invoice.lineCount == 1 ? "1 line" : "\(invoice.lineCount) lines"
        return "AI read \(lines). Check each one, then confirm."
    }
}
