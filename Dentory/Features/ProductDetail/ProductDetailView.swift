import SwiftUI

/// Product detail (f20 Admin, f21 Staff): context header, name and status, the quantity card, Adjust and
/// Add to buy, the expiry card, the bottles card for multi-use products, the history, and Delete product
/// for Admin. Its sheets (Edit, Delete, Adjust, Add expiry, Edit batch) are drawn by `ProductDetailSheet`;
/// the bottles are opened and finished in place (MS-120); the full history opens its own ticket's screen later.
struct ProductDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProductDetailViewModel
    let session: Session

    init(productID: UUID, session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(
            initialValue: dependencies.makeProductDetailViewModel(productID: productID, session: session)
        )
    }

    var body: some View {
        content
            .pushedScreen(
                title: viewModel.contextLine,
                identifier: "product",
                action: session.isAdmin
                    ? .init(title: "Edit", identifier: "product.edit", perform: viewModel.edit) : nil,
                style: .context
            )
            .reloadOnReturn { await viewModel.load() }
            .onChange(of: viewModel.generalError) { _, error in
                guard let error else { return }
                dependencies.toasts.show(error.userMessage)
                viewModel.clearGeneralError()
            }
            .onChange(of: viewModel.addedToBuy) { _, added in
                guard let added else { return }
                dependencies.toasts.show(added.title, detail: added.detail) {
                    Task { await viewModel.undoAddToBuy() }
                }
                viewModel.clearAddedToBuy()
            }
            .onChange(of: viewModel.isDeleted) { _, isDeleted in
                guard isDeleted else { return }
                dependencies.toasts.show("Product deleted")
                dismiss()
            }
            .onChange(of: viewModel.bottleToast) { _, toast in
                guard let toast else { return }
                dependencies.toasts.show(toast.title, detail: toast.detail)
                viewModel.clearBottleToast()
            }
            .onChange(of: viewModel.adjusted) { _, adjusted in
                guard let adjusted else { return }
                // Undo needs the server's action id; a write queued offline has none (MS-100 D10).
                var undo: (@MainActor () -> Void)?
                if adjusted.actionID != nil {
                    undo = { Task { await viewModel.undoAdjustment() } }
                }
                dependencies.toasts.show(adjusted.title, detail: adjusted.detail, undo: undo)
                viewModel.clearAdjusted()
            }
            .msSheet(item: $viewModel.sheet) { sheet in
                ProductDetailSheet(sheet: sheet, viewModel: viewModel, session: session)
            }
    }

    @ViewBuilder private var content: some View {
        if let detail = viewModel.detail {
            ProductTitleRow(name: detail.name, status: detail.status)
            ProductQuantityCard(viewModel: viewModel)
            ProductActionsRow(viewModel: viewModel)
            ProductExpiryCard(viewModel: viewModel, onBatch: viewModel.editBatch, onAddExpiry: viewModel.addExpiry)
            if viewModel.isMultiUse {
                ProductBottlesCard(viewModel: viewModel, onFinished: finishBottle, onOpenNew: openNewBottle)
            }
            ProductHistoryCard(rows: viewModel.historyRows, onShowAll: showAllHistory)
            if session.isAdmin {
                Button(action: viewModel.askToDelete) {
                    HStack(spacing: Spacing.sm) {
                        IconView(.trash, size: 16)
                        Text("Delete product")
                    }
                }
                .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
                .accessibilityIdentifier("product.delete")
            }
        } else if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else {
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("product.loading")
        }
    }

    private func finishBottle(_ id: UUID) { Task { await viewModel.finishBottle(id) } }
    private func openNewBottle() { Task { await viewModel.openNewBottle() } }

    // Placeholders until the tickets that bring these screens (MS-134).
    private func showAllHistory() { dependencies.toasts.show("History arrives with a later update.") }
}

#Preview("Product detail · Admin") {
    NavigationStack {
        ProductDetailView(productID: ProductSummary.demo[0].id, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo)
}
