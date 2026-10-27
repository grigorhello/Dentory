import SwiftUI

/// Inventory's search field over its status chips, pinned under the title while the rows scroll (f16-2), also while
/// counting (f18-2). The removable category chip comes first when a category was handed over.
struct InventorySearchAndFilters: View {
    @Bindable var viewModel: InventoryListViewModel

    var body: some View {
        MSTextField(
            nil, text: $viewModel.searchText, identifier: "inv.search", placeholder: "Search products", icon: .search
        )
        .submitLabel(.search)
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
        // The 36 pt chips sit 4 pt inside their 44 pt row; its last 4 pt reach into the strip under the pinned
        // controls, so the rows are cut 4 pt under the chips (f16-2) and the chips keep their whole hit area.
        .padding(.bottom, -Spacing.xs)
        .accessibilityIdentifier("inv.filter")
    }
}
