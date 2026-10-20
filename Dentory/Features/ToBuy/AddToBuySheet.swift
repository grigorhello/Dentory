import SwiftUI

/// "Add to To buy" (Appendix C `addOrder`): search, a 360 pt list of the products not on the list yet with their
/// stock, and + per row, which adds the product with its suggested quantity and closes the sheet.
struct AddToBuySheet: View {
    @Bindable var viewModel: ToBuyViewModel

    var body: some View {
        SheetList(
            "Add to To buy", identifier: "addOrder", searchText: $viewModel.searchText,
            emptyText: viewModel.addItemEmptyText, items: viewModel.addableProducts
        ) { product in
            ListRow(product.name, caption: viewModel.addCaption(for: product)) {
                IconButton(.plus, label: "Add \(product.name)", variant: .outline, size: .small) {
                    Task { await viewModel.add(product) }
                }
                .accessibilityIdentifier("addOrder.row[\(product.id.uuidString.lowercased())].add")
            }
        }
        .task { await viewModel.loadProducts() }
    }
}
