import SwiftUI

/// "Add item" (Appendix C `addItem`): search, a 360 pt list of the products not on the procedure yet with
/// "40 needles in stock" (multi-use: "1 unopened · 2 open"), and + per row: a countable product joins with 1, a
/// multi-use one is taken new. What goes wrong is said inside the sheet, where it can be seen: "Out of stock" on the
/// row tapped, and a failed load in place of the list.
struct AddProcedureItemSheet: View {
    @Bindable var viewModel: ProcedureStartViewModel

    var body: some View {
        SheetList(
            "Add item", identifier: "addItem", searchText: $viewModel.searchText,
            emptyText: viewModel.addItemEmptyText, items: viewModel.addableProducts
        ) { product in
            ListRow(
                product.name, caption: viewModel.addCaption(for: product),
                captionTone: viewModel.addCaptionTone(for: product)
            ) {
                IconButton(.plus, label: "Add \(product.name)", variant: .outline, size: .small) {
                    viewModel.add(product)
                }
                .accessibilityIdentifier("addItem.row[\(product.id.uuidString.lowercased())].add")
            }
        }
        .task { await viewModel.loadProducts() }
        .onChange(of: viewModel.outOfStockProductID) { _, productID in
            guard productID != nil else { return }
            AccessibilityNotification.Announcement("Out of stock").post()
        }
    }
}
