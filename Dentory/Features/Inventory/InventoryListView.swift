import SwiftUI

/// Inventory (f16 Admin, f17 Staff, f19 Low filter): title with Count stock, search, status chips and
/// the product rows in one card; Admin gets the round + for New product.
struct InventoryListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.tabBarInset) private var tabBarInset
    @Environment(AppRouter.self) private var router
    @State private var viewModel: InventoryListViewModel
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeInventoryListViewModel(session: session))
    }

    var body: some View {
        content
            .rootScreen(title: "Inventory", identifier: "inv.header") {
                MSButton("Count stock", icon: .clipboardList, variant: .tertiary, size: .small, action: countStock)
                    .accessibilityIdentifier("inv.countStock")
            }
            // Floats over the rows, 20 pt above the tab bar (f16); the list leaves room under its last row.
            .overlay(alignment: .bottomTrailing) {
                FloatingAddButton(label: "New product", action: newProduct)
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, Spacing.page + tabBarInset)
                    .accessibilityIdentifier("inv.newProduct")
                    .adminOnly()
            }
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: InventoryRoute.self) { route in
                InventoryRoutePlaceholderView(route: route)
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
            InventoryEmptyClinic(isAdmin: session.isAdmin) { router.push(InventoryRoute.receive, on: .inventory) }
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
        case nil:
            InventoryRows(viewModel: viewModel)
            if session.isAdmin {
                // Room for the round + button, so it never covers the last row.
                Color.clear.frame(height: FloatingAddButton.diameter + Spacing.page)
            }
        }
    }

    /// Count mode arrives with MS-121.
    private func countStock() {
        dependencies.toasts.show("Count stock arrives with a later update.")
    }

    /// The New product sheet arrives with MS-117.
    private func newProduct() {
        dependencies.toasts.show("New product arrives with a later update.")
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
}

#Preview("Inventory · Staff") {
    NavigationStack {
        InventoryListView(session: .demo(role: .staff), dependencies: .preview(role: .staff))
    }
    .environment(AppRouter(selectedTab: .inventory))
    .environment(\.session, Session.demo(role: .staff))
}
