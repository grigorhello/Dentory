import SwiftUI

/// "Discard this invoice?" (the ticket's Discard invoice, PRD §7 destructive): one sentence of what happens, the danger
/// Discard invoice, and Keep.
struct DiscardInvoiceSheet: View {
    let viewModel: InvoiceViewModel

    var body: some View {
        MSSheet(InvoiceViewModel.discardQuestion, identifier: "invoice.discard") {
            Text(InvoiceViewModel.discardMessage)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("invoice.discard.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    InvoiceViewModel.discardTitle, variant: .danger, isFullWidth: true,
                    isLoading: viewModel.isDiscarding, action: discard
                )
                .accessibilityIdentifier("invoice.discard.confirm")
                MSButton(InvoiceViewModel.keepTitle, variant: .text, isFullWidth: true, action: viewModel.keepInvoice)
                    .accessibilityIdentifier("invoice.discard.keep")
            }
        }
    }

    private func discard() {
        Task { await viewModel.discard() }
    }
}
