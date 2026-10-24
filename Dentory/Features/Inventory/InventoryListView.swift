import SwiftUI

/// Inventory (f16 Admin, f17 Staff, f19 Low filter): title with Count stock, search, status chips and
/// the product rows in one card; Admin gets the round + for New product. Count stock (f18, MS-121) turns the
/// same list into steppers with Cancel in the header and Review pinned above the tab bar.
struct InventoryListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: InventoryListViewModel
    @State private var isNewProductPresented = false
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeInventoryListViewModel(session: session))
    }

    var body: some View {
        content
            .rootScreen(title: viewModel.title, identifier: "inv.header") {
                InventoryHeaderAction(viewModel: viewModel)
            }
            // Floats over the rows, 20 pt above the tab bar (f16); the list leaves room under its last row.
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.isCounting {
                    FloatingAddButton(label: "New product", action: newProduct)
                        .padding(.horizontal, Spacing.page)
                        .padding(.bottom, Spacing.page)
                        .accessibilityIdentifier("inv.newProduct")
                        .adminOnly()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.isCounting {
                    CountReviewBar(viewModel: viewModel)
                }
            }
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: InventoryRoute.self) { route in
                switch route {
                case .product(let id):
                    ProductDetailView(productID: id, session: session, dependencies: dependencies)
                case .receive:
                    ReceiveView(session: session, dependencies: dependencies)
                }
            }
            .onChange(of: router.inventoryFilter, initial: true) { _, filter in
                guard let filter else { return }
                viewModel.apply(filter: filter)
                router.inventoryFilter = nil
            }
            .onChange(of: router.inventoryCategory, initial: true) { _, category in
                guard let category else { return }
                viewModel.apply(category: category)
                router.inventoryCategory = nil
            }
            .msSheet(isPresented: $isNewProductPresented) {
                ProductFormSheet(mode: .create, session: session, dependencies: dependencies) { _ in
                    isNewProductPresented = false
                    dependencies.toasts.show("Product created")
                    Task { await viewModel.load() }
                }
            }
            .msSheet(item: $viewModel.countSheet) { sheet in
                CountSheetView(sheet: sheet, viewModel: viewModel)
            }
            .onChange(of: viewModel.countApplied) { _, applied in
                guard let applied else { return }
                dependencies.toasts.show(applied.title, detail: applied.detail)
                viewModel.clearCountApplied()
            }
    }

    @ViewBuilder private var content: some View {
        MSTextField(
            nil, text: $viewModel.searchText, identifier: "inv.search", placeholder: "Search products", icon: .search
        )
        .submitLabel(.search)
        InventoryFilterChips(viewModel: viewModel)
        switch viewModel.emptyReason {
        case .noMatches:
            EmptyStateView("No products match.")
        case .noProducts:
            InventoryEmptyClinic(isAdmin: session.isAdmin) {
                writeAccess.perform { router.push(InventoryRoute.receive, on: .inventory) }
            }
        case nil where viewModel.products.isEmpty:
            if case .failed(let error) = viewModel.state {
                Notice(error.userMessage, tone: .danger)
            } else {
                ListCard {
                    SkeletonRow()
                    SkeletonRow()
                    SkeletonRow(showsDivider: false)
                }
                .accessibilityIdentifier("inv.loading")
            }
        case nil where viewModel.isCounting:
            InventoryCountRows(viewModel: viewModel)
        case nil:
            InventoryRows(viewModel: viewModel)
            if session.isAdmin {
                // Room for the round + button, so it never covers the last row.
                Color.clear.frame(height: FloatingAddButton.diameter + Spacing.page)
            }
        }
    }

    /// The New product sheet (MS-117); in read-only mode the read-only sheet says why instead (MS-142).
    private func newProduct() {
        writeAccess.perform { isNewProductPresented = true }
    }
}

/// The status chips, with the removable category chip in front when a category was handed over.
private struct InventoryFilterChips: View {
    @Bindable var viewModel: InventoryListViewModel

    var body: some View {
        FilterChipRow(
            selection: $viewModel.filter,
            options: InventoryFilter.allCases.map { SegmentOption($0, label: $0.rawValue) }
        ) {
            if let category = viewModel.category {
                FilterChip("\(category) ×", isSelected: true) { viewModel.clearCategory() }
                    .accessibilityLabel("Remove the \(category) filter")
                    .accessibilityIdentifier("inv.filter.category")
            }
        }
        .padding(.horizontal, -Spacing.page)
        .accessibilityIdentifier("inv.filter")
    }
}

/// The product rows in one card, lazily, so 500 products scroll without jank.
private struct InventoryRows: View {
    let viewModel: InventoryListViewModel

    var body: some View {
        let rows = viewModel.visibleProducts
        ListCard {
            LazyVStack(spacing: 0) {
                ForEach(rows) { product in
                    NavigationLink(value: InventoryRoute.product(product.id)) {
                        ProductRow(
                            product: product,
                            caption: viewModel.caption(for: product),
                            showsDivider: product.id != rows.last?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inv.row[\(product.id.uuidString.lowercased())]")
                }
            }
        }
    }
}

/// A clinic without products: Admin is sent to Receive delivery, Staff only told.
private struct InventoryEmptyClinic: View {
    let isAdmin: Bool
    let onReceive: () -> Void

    var body: some View {
        if isAdmin {
            EmptyStateView("No products yet. Receive a delivery to add them.")
            MSButton("Receive delivery", icon: .truck, variant: .tertiary, isFullWidth: true, action: onReceive)
                .accessibilityIdentifier("inv.receive")
        } else {
            EmptyStateView("No products yet.")
        }
    }
}

#Preview("Inventory · Admin") {
    NavigationStack {
        InventoryListView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo)
}

#Preview("Inventory · Staff") {
    NavigationStack {
        InventoryListView(session: .demo(role: .staff), dependencies: .preview(role: .staff))
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo(role: .staff))
}
