import SwiftUI

/// The invoices being read, ready to review or whose reading failed, above "Waiting for delivery" (PRD §6.5):
/// "Continue reviewing" over "Patterson · 8:55 AM", or "Couldn't read · 9:41 AM", each opening Review invoice.
struct ReceiveInvoiceList: View {
    let viewModel: ReceiveViewModel
    let onContinue: (PendingInvoice) -> Void

    var body: some View {
        ListCard {
            ForEach(viewModel.invoices) { invoice in
                Button {
                    onContinue(invoice)
                } label: {
                    ReceiveRow(
                        title: ReceiveViewModel.continueTitle, caption: viewModel.invoiceLine(for: invoice),
                        navigates: true, showsDivider: invoice.id != viewModel.invoices.last?.id
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("receive.continue[\(invoice.id.uuidString.lowercased())]")
            }
        }
    }
}
