import SwiftUI

/// Delete invoice file over Review invoice (MS-146): the question the header's "…" menu opens on a received invoice,
/// then the invoice shown without its file and the toast.
struct InvoiceFileDeletionModifier: ViewModifier {
    @Environment(\.appDependencies) private var dependencies
    @Bindable var viewModel: InvoiceViewModel
    let session: Session

    func body(content: Content) -> some View {
        content
            .msSheet(isPresented: $viewModel.isConfirmingFileDeletion) {
                DeleteInvoiceFileSheet(
                    viewModel: dependencies.makeDeleteInvoiceFileViewModel(
                        invoiceID: viewModel.invoiceID, session: session
                    ),
                    onKeep: viewModel.keepFile, onDeleted: deleted
                )
            }
    }

    /// The file is gone: the invoice shows without it, and the toast says so.
    private func deleted(_ invoice: InvoiceSummary) {
        viewModel.fileDeleted(invoice)
        dependencies.toasts.show(InvoiceViewModel.fileDeletedTitle)
    }
}

extension View {
    /// Delete invoice file's question, driven by Review invoice's view model (MS-146).
    func invoiceFileDeletion(_ viewModel: InvoiceViewModel, session: Session) -> some View {
        modifier(InvoiceFileDeletionModifier(viewModel: viewModel, session: session))
    }
}
