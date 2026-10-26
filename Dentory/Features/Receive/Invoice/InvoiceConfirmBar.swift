import SwiftUI

/// Review invoice's pinned bar (f23): `invoice.summary`, "Resolve every line to continue." or "3 of 4 lines will
/// increase inventory.", over Confirm & receive (`invoice.confirm`), disabled until every line is resolved. Receiving
/// is a write: in read-only mode the sheet says why instead (MS-142). Once the delivery is in, Inventory opens at the
/// root of its tab with every product shown, under "Delivery received · Inventory increased for N products." and its
/// Undo (PRD §6.5, MS-131).
struct InvoiceConfirmBar: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    let viewModel: InvoiceReviewViewModel

    var body: some View {
        PinnedPrimaryBar(caption: viewModel.summary, captionIdentifier: "invoice.summary") {
            MSButton(
                InvoiceReviewViewModel.confirmTitle, icon: .check, isFullWidth: true,
                isLoading: viewModel.isConfirming, isDisabled: !viewModel.canConfirm, action: confirm
            )
            .accessibilityIdentifier("invoice.confirm")
        }
        .onChange(of: viewModel.receipt.received) { _, received in openInventory(with: received) }
        .onChange(of: viewModel.receipt.generalError) { _, error in show(error) }
    }

    private func confirm() {
        writeAccess.perform {
            Task { await viewModel.confirm() }
        }
    }

    /// The delivery is in: Inventory at the root of its tab with every product shown, as the prototype opens it, and
    /// the toast, whose Undo runs after this screen has gone, while the server's action is known (MS-100 D10).
    private func openInventory(with received: InvoiceReceiptViewModel.Received?) {
        guard let received else { return }
        let receipt = viewModel.receipt
        let toasts = dependencies.toasts
        router.popToRoot(on: router.selectedTab)
        router.popToRoot(on: .inventory)
        router.inventoryFilter = .all
        router.selectedTab = .inventory
        var undo: (@MainActor () -> Void)?
        if let actionID = received.actionID {
            undo = {
                Task {
                    if let error = await receipt.undo(actionID) { toasts.show(error.userMessage) }
                }
            }
        }
        toasts.show(received.title, detail: received.detail, undo: undo)
    }

    /// A refused confirmation, as a toast; the lines stay as they are, or show as the server has them now.
    private func show(_ error: AppError?) {
        guard let error else { return }
        dependencies.toasts.show(error.userMessage)
        viewModel.receipt.clearGeneralError()
    }
}
