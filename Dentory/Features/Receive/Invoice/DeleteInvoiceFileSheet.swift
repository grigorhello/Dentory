import SwiftUI

/// "Delete the invoice file?" (MS-146, PRD §7 destructive): what stays and what goes in one sentence, what went wrong
/// above the buttons, the danger Delete file and Keep. `onDeleted` receives the invoice without its file. The sheet
/// stays while the file is being deleted.
struct DeleteInvoiceFileSheet: View {
    @State private var viewModel: DeleteInvoiceFileViewModel
    let onKeep: () -> Void
    let onDeleted: (InvoiceSummary) -> Void

    init(
        viewModel: DeleteInvoiceFileViewModel, onKeep: @escaping () -> Void,
        onDeleted: @escaping (InvoiceSummary) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onKeep = onKeep
        self.onDeleted = onDeleted
    }

    var body: some View {
        MSSheet(DeleteInvoiceFileViewModel.title, identifier: "invoice.deleteFile") {
            Text(DeleteInvoiceFileViewModel.message)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("invoice.deleteFile.message")
            if let error = viewModel.generalError {
                Notice(error.userMessage, tone: .danger, identifier: "invoice.deleteFile.error")
            }
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    DeleteInvoiceFileViewModel.deleteTitle, variant: .danger, isFullWidth: true,
                    isLoading: viewModel.isDeleting, action: delete
                )
                .accessibilityIdentifier("invoice.deleteFile.confirm")
                MSButton(
                    DeleteInvoiceFileViewModel.keepTitle, variant: .text, isFullWidth: true,
                    isDisabled: viewModel.isDeleting, action: onKeep
                )
                .accessibilityIdentifier("invoice.deleteFile.keep")
            }
        }
        .interactiveDismissDisabled(viewModel.isDeleting)
        .onChange(of: viewModel.deleted) { _, deleted in
            guard let deleted else { return }
            onDeleted(deleted)
        }
    }

    private func delete() {
        Task { await viewModel.delete() }
    }
}

#Preview("Delete the invoice file?") {
    @Previewable @State var isPresented = true
    Color.ms.canvas
        .msSheet(isPresented: $isPresented) {
            DeleteInvoiceFileSheet(
                viewModel: DeleteInvoiceFileViewModel(
                    invoiceID: DemoInvoiceRepository.readyID, clinicID: Session.demo.clinicID,
                    repository: DemoInvoiceRepository(launched: nil)
                ),
                onKeep: { isPresented = false }, onDeleted: { _ in isPresented = false }
            )
        }
}
