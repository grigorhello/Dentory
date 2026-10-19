import SwiftUI

/// Product detail (f20 Admin, f21 Staff): context header, name and status, the quantity card, Adjust and
/// Add to buy, the expiry card, the bottles card for multi-use products, the history, and Delete product
/// for Admin. Edit, Adjust, batches, bottles, history and Delete open their own tickets' screens later.
struct ProductDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
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
            .msSheet(item: $viewModel.sheet) { sheet in
                switch sheet {
                case .edit:
                    if let detail = viewModel.detail {
                        ProductFormSheet(mode: .edit(detail), session: session, dependencies: dependencies) { _ in
                            dependencies.toasts.show("Changes saved")
                            Task { await viewModel.productSaved() }
                        }
                    }
                case .delete:
                    DeleteProductSheet(
                        title: viewModel.deleteTitle, message: viewModel.deleteMessage,
                        isDeleting: viewModel.isSubmitting,
                        onDelete: { Task { await viewModel.deleteProduct() } },
                        onKeep: viewModel.keepProduct
                    )
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
        MSButton("Adjust", icon: .slidersHorizontal, variant: .tertiary, isFullWidth: isFullWidth, action: adjust)
            .accessibilityIdentifier("product.adjust")
    }

    private var addToBuyButton: some View {
        MSButton(
            viewModel.addToBuyTitle, icon: .shoppingCart, isFullWidth: true, isLoading: viewModel.isSubmitting,
            action: addToBuy
        )
        .accessibilityIdentifier("product.addToBuy")
    }

    private func addToBuy() {
        if viewModel.isOnToBuy {
            router.select(.toBuy)
        } else {
            Task { await viewModel.addToBuy() }
        }
    }

    // Placeholders until the tickets that bring these screens (MS-118 to MS-120, MS-134).
    private func adjust() { dependencies.toasts.show("Adjust arrives with a later update.") }
    private func editBatch(_ id: UUID) { dependencies.toasts.show("Edit batch arrives with a later update.") }
    private func addExpiry() { dependencies.toasts.show("Add expiry arrives with a later update.") }
    private func finishBottle(_ id: UUID) { dependencies.toasts.show("Finished arrives with a later update.") }
    private func openNewBottle() { dependencies.toasts.show("Open a new bottle arrives with a later update.") }
    private func showAllHistory() { dependencies.toasts.show("History arrives with a later update.") }
}

#Preview("Product detail · Admin") {
    NavigationStack {
        ProductDetailView(productID: ProductSummary.demo[0].id, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo)
}
