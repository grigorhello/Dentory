import SwiftUI

/// Product detail (f20 Admin, f21 Staff): context header, name and status, the quantity card, Adjust and
/// Add to buy, the expiry card, the bottles card for multi-use products, the history, and Delete product
/// for Admin. Its sheets (Edit, Delete, Adjust, Add expiry, Edit batch) are drawn by `ProductDetailSheet`;
/// the bottles are opened and finished in place (MS-120); Show all opens the product's history (MS-134).
struct ProductDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.writeAccess) private var writeAccess
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
                action: session.isAdmin ? .init(title: "Edit", identifier: "product.edit", perform: edit) : nil,
                style: .context
            )
            .reloadOnReturn { await viewModel.load() }
            .tabDestination(for: ProductDetailRoute.self) { route in
                switch route {
                case .history(let productID, let name):
                    ActivityHistoryView(
                        productID: productID, productName: name, session: session, dependencies: dependencies
                    )
                }
            }
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
            ProductExpiryCard(viewModel: viewModel, onBatch: editBatch, onAddExpiry: addExpiry)
            if viewModel.isMultiUse {
                ProductBottlesCard(viewModel: viewModel, onFinished: finishBottle, onOpenNew: openNewBottle)
            }
            ProductHistoryCard(rows: viewModel.historyRows, onShowAll: showAllHistory)
            if session.isAdmin {
                Button(action: deleteProduct) {
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

    /// Open a new bottle, Finished, Edit, Delete product, Add expiry and Edit batch open the read-only sheet
    /// instead in read-only mode (MS-142); Adjust and Add to buy do the same in `ProductActionsRow`.
    private func finishBottle(_ id: UUID) { writeAccess.perform { Task { await viewModel.finishBottle(id) } } }
    private func openNewBottle() { writeAccess.perform { Task { await viewModel.openNewBottle() } } }
    private func edit() { writeAccess.perform(viewModel.edit) }
    private func deleteProduct() { writeAccess.perform(viewModel.askToDelete) }
    private func addExpiry() { writeAccess.perform(viewModel.addExpiry) }
    private func editBatch(_ id: UUID) { writeAccess.perform { viewModel.editBatch(id) } }

    /// The product's whole history (MS-134).
    private func showAllHistory() {
        guard let detail = viewModel.detail else { return }
        router.push(ProductDetailRoute.history(productID: detail.id, name: detail.name))
    }
}

#Preview("Product detail · Admin") {
    NavigationStack {
        ProductDetailView(productID: ProductSummary.demo[0].id, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo)
}
