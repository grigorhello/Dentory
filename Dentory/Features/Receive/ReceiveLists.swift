import SwiftUI

/// Under Receive delivery's options (f22): the invoices to continue reviewing, then "Waiting for delivery" with the
/// lines marked Ordered. Each part hides when it has nothing; while nothing has loaded yet, placeholder rows stand in.
struct ReceiveLists: View {
    let viewModel: ReceiveViewModel
    let onContinue: (PendingInvoice) -> Void

    var body: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.state == .loading && viewModel.overview == nil {
            ListCard {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("receive.loading")
        } else {
            if !viewModel.invoices.isEmpty {
                ReceiveInvoiceList(viewModel: viewModel, onContinue: onContinue)
            }
            if !viewModel.waiting.isEmpty {
                ReceiveWaitingList(viewModel: viewModel)
            }
        }
    }
}
