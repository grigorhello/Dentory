import SwiftUI

/// "Add item" (Appendix C `addItem`): search, a 360 pt list of the products not on the procedure yet with
/// "40 needles in stock" (multi-use: "1 unopened · 2 open"), and + per row: a countable product joins with 1, a
/// multi-use one is taken new.
struct AddProcedureItemSheet: View {
    @Bindable var viewModel: ProcedureStartViewModel

    var body: some View {
        SheetList(
            "Add item", identifier: "addItem", searchText: $viewModel.searchText,
            emptyText: viewModel.addItemEmptyText, items: viewModel.addableProducts
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
