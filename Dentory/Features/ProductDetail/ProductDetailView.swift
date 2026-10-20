import SwiftUI

/// Product detail (f20 Admin, f21 Staff): context header, name and status, the quantity card, Adjust and
/// Add to buy, the expiry card, the bottles card for multi-use products, the history, and Delete product
/// for Admin. Show all opens the product's history (MS-134); Edit, batches and Delete open their own tickets'
/// screens later.
struct ProductDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
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
            .navigationDestination(for: ProductDetailRoute.self) { route in
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
                switch sheet {
                case .adjust:
                    if let adjustViewModel = viewModel.makeAdjustInventoryViewModel() {
                        AdjustInventorySheet(viewModel: adjustViewModel) { saved in
                            Task { await viewModel.adjustmentSaved(saved) }
                        }
                    }
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let detail = viewModel.detail {
            ProductTitleRow(name: detail.name, status: detail.status)
            ProductQuantityCard(viewModel: viewModel)
            actions
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

    /// Adjust beside Add to buy in equal halves (f20); when a label does not fit its half, Adjust keeps its
    /// own width and the primary button takes the rest, and on a narrower screen the two stack.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            EqualWidthHStack(spacing: Spacing.md) {
                adjustButton(isFullWidth: true)
                addToBuyButton
            }
            HStack(spacing: Spacing.md) {
                adjustButton(isFullWidth: false)
                addToBuyButton
            }
            VStack(spacing: Spacing.md) {
                adjustButton(isFullWidth: true)
                addToBuyButton
            }
        }
    }

    private func adjustButton(isFullWidth: Bool) -> some View {
        MSButton("Adjust", icon: .slidersHorizontal, variant: .tertiary, isFullWidth: isFullWidth) {
            writeAccess.perform(viewModel.openAdjust)
        }
        .accessibilityIdentifier("product.adjust")
    }

    private var addToBuyButton: some View {
        MSButton(
            viewModel.addToBuyTitle, icon: .shoppingCart, isFullWidth: true, isLoading: viewModel.isSubmitting,
            action: addToBuy
        )
        .accessibilityIdentifier("product.addToBuy")
    }

    /// Adjust, Add to buy, Open a new bottle and Finished open the read-only sheet instead in read-only mode (MS-142);
    /// "On To buy" only goes to the list.
    private func addToBuy() {
        if viewModel.isOnToBuy {
            router.select(.toBuy)
        } else {
            writeAccess.perform { Task { await viewModel.addToBuy() } }
        }
    }

    private func finishBottle(_ id: UUID) { writeAccess.perform { Task { await viewModel.finishBottle(id) } } }
    private func openNewBottle() { writeAccess.perform { Task { await viewModel.openNewBottle() } } }

    // Placeholders until the tickets that bring these screens (MS-117, MS-119, MS-134); each opens the read-only
    // sheet instead in read-only mode (MS-142).
    private func edit() {
        writeAccess.perform { dependencies.toasts.show("Edit product arrives with a later update.") }
    }
    private func editBatch(_ id: UUID) {
        writeAccess.perform { dependencies.toasts.show("Edit batch arrives with a later update.") }
    }
    private func addExpiry() {
        writeAccess.perform { dependencies.toasts.show("Add expiry arrives with a later update.") }
    }
    /// The product's whole history (MS-134).
    private func showAllHistory() {
        guard let detail = viewModel.detail else { return }
        router.push(ProductDetailRoute.history(productID: detail.id, name: detail.name))
    }
    private func deleteProduct() {
        writeAccess.perform { dependencies.toasts.show("Delete product arrives with a later update.") }
    }
}

#Preview("Product detail · Admin") {
    NavigationStack {
        ProductDetailView(productID: ProductSummary.demo[0].id, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo)
}
