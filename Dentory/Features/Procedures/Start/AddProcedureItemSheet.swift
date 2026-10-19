import SwiftUI

/// "Add item" (Appendix C `addItem`): search, a 360 pt list of the products not on the procedure yet with
/// "40 needles in stock", and + per row, which appends the product with quantity 1.
struct AddProcedureItemSheet: View {
    @Bindable var viewModel: ProcedureStartViewModel

    var body: some View {
        SheetList(
            "Add item", identifier: "addItem", searchText: $viewModel.searchText, items: viewModel.addableProducts
        ) { product in
            ListRow(product.name, caption: viewModel.addCaption(for: product)) {
                IconButton(.plus, label: "Add \(product.name)", variant: .outline, size: .small) {
                    viewModel.add(product)
                }
                .accessibilityIdentifier("addItem.row[\(product.id.uuidString.lowercased())].add")
            }
        }
        .task { await viewModel.loadProducts() }
    }
}
