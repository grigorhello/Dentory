import SwiftUI

/// Inventory value (f10), pushed from Home's Inventory value tile for Admin and Staff: the total card, the value by
/// category (a row opens Inventory filtered by it) and the five most valuable products (a row opens Product detail).
struct InventoryValueView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var viewModel: InventoryValueViewModel
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeInventoryValueViewModel(session: session))
    }

    var body: some View {
        content
            .pushedScreen(title: "Inventory value", identifier: "value")
            .reloadOnReturn { await viewModel.load() }
            .tabDestination(for: InventoryValueRoute.self) { route in
                switch route {
                case .product(let productID):
                    ProductDetailView(productID: productID, session: session, dependencies: dependencies)
                }
            }
    }

    @ViewBuilder private var content: some View {
        if viewModel.value != nil {
            InventoryValueTotalCard(total: viewModel.totalText, stats: viewModel.stats)
            if let uncosted = viewModel.uncostedText {
                Text(uncosted)
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .accessibilityIdentifier("value.uncosted")
            }
            if viewModel.isEmpty {
                EmptyStateView(InventoryValueViewModel.emptyText)
            } else {
                categoriesSection
                productsSection
            }
            Text(InventoryValueViewModel.footnote)
                .textStyle(.micro12)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else {
            VStack(spacing: Spacing.md) {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("value.loading")
        }
    }

    private var categoriesSection: some View {
        let categories = viewModel.categories
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow("By category").accessibilityAddTraits(.isHeader)
            ListCard {
                ForEach(categories) { category in
                    let row = InventoryValueCategoryRow(
                        name: viewModel.name(of: category), value: viewModel.valueText(of: category),
                        shareText: viewModel.shareText(of: category), share: viewModel.share(of: category),
                        showsDivider: category.id != categories.last?.id
                    )
                    if let filter = viewModel.filter(for: category) {
                        Button { showInInventory(filter) } label: { row }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens Inventory filtered by \(filter)")
                            .accessibilityIdentifier("value.row[\(category.id)]")
                    } else {
                        row.accessibilityIdentifier("value.row[\(category.id)]")
                    }
                }
            }
        }
    }

    private var productsSection: some View {
        let products = viewModel.topProducts
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow("Highest value products").accessibilityAddTraits(.isHeader)
            ListCard {
                ForEach(products) { product in
                    NavigationLink(value: InventoryValueRoute.product(product.id)) {
                        ListRow(
                            product.name, caption: viewModel.line(for: product),
                            value: viewModel.valueText(of: product), navigates: true,
                            showsDivider: product.id != products.last?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("value.product[\(product.id.uuidString.lowercased())]")
                }
            }
        }
    }

    /// Inventory, at its list, narrowed to the category (MS-115 shows it as a removable chip).
    private func showInInventory(_ category: String) {
        router.inventoryCategory = category
        router.popToRoot(on: .inventory)
        router.select(.inventory)
    }
}

#Preview("Inventory value") {
    NavigationStack {
        InventoryValueView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}
