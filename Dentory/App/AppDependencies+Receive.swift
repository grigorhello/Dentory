import Foundation

/// Receive delivery's, Receive manually's and Review invoice's view models (MS-126, MS-127, MS-129 to MS-131, MS-146),
/// kept apart from the composition root's body.
extension AppDependencies {
    /// Receive delivery of the signed-in clinic, for its admin (MS-126). `canScan` says whether Take a photo opens the
    /// document scanner or, on a device without one, Photos.
    @MainActor
    func makeReceiveViewModel(session: Session, canScan: Bool) -> ReceiveViewModel {
        ReceiveViewModel(
            repository: receiveRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, canScan: canScan
        )
    }

    /// Receive manually for the signed-in clinic's admin (MS-127), with `productID` already chosen when the route names
    /// one.
    @MainActor
    func makeManualReceiveViewModel(productID: UUID?, session: Session) -> ManualReceiveViewModel {
        ManualReceiveViewModel(
            repository: manualReceiveRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, productID: productID, analytics: analytics
        )
    }

    /// Review invoice for pages just captured: it uploads them as the invoice `document.id` and follows the reading
    /// (MS-129).
    @MainActor
    func makeInvoiceViewModel(document: InvoiceDocument, session: Session) -> InvoiceViewModel {
        InvoiceViewModel(
            document: document, repository: invoiceRepository, formatters: formatters(for: session),
            clinicID: session.clinicID, analytics: analytics
        )
    }

    /// Review invoice for an invoice being read, ready to review or received (MS-129 to MS-131).
    @MainActor
    func makeInvoiceViewModel(invoiceID: UUID, session: Session) -> InvoiceViewModel {
        InvoiceViewModel(
            invoiceID: invoiceID, repository: invoiceRepository, formatters: formatters(for: session),
            clinicID: session.clinicID, analytics: analytics
        )
    }

    /// Delete the invoice file? for a received invoice of the signed-in clinic (MS-146).
    @MainActor
    func makeDeleteInvoiceFileViewModel(invoiceID: UUID, session: Session) -> DeleteInvoiceFileViewModel {
        DeleteInvoiceFileViewModel(invoiceID: invoiceID, clinicID: session.clinicID, repository: invoiceRepository)
    }

    /// Which product is this? for an invoice line (MS-130): the products Receive manually lists too.
    @MainActor
    func makeInvoiceMatchViewModel(line: InvoiceLine, session: Session) -> InvoiceMatchViewModel {
        InvoiceMatchViewModel(
            line: line, repository: manualReceiveRepository, formatters: formatters(for: session),
            clinicID: session.clinicID
        )
    }
}
