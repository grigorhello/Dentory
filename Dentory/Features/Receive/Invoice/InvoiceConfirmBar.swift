import SwiftUI

/// Review invoice's pinned bar (f23): `invoice.summary`, "Resolve every line to continue." or "3 of 4 lines will
/// increase inventory.", over Confirm & receive (`invoice.confirm`), disabled until every line is resolved. Receiving
/// is a write: in read-only mode the sheet says why instead (MS-142).
struct InvoiceConfirmBar: View {
    @Environment(\.writeAccess) private var writeAccess
    let viewModel: InvoiceReviewViewModel

    var body: some View {
        PinnedPrimaryBar(caption: viewModel.summary, captionIdentifier: "invoice.summary") {
            MSButton(
                InvoiceReviewViewModel.confirmTitle, icon: .check, isFullWidth: true,
                isDisabled: !viewModel.canConfirm, action: confirm
            )
            .accessibilityIdentifier("invoice.confirm")
        }
    }

    private func confirm() {
        writeAccess.perform(viewModel.confirm)
    }
}
