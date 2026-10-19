import SwiftUI

/// "Add item" (Appendix C `addItem`): search, a 360 pt list of the products not on the list yet with the caption the
/// screen gives each ("40 needles in stock" on Adjust, then start; "Anesthetic · multi-use" on Edit procedure), and
/// + per row, which hands the product to the screen. What goes wrong is said inside the sheet, where it can be seen:
/// "Out of stock" on the row tapped, and a failed load in place of the list.
struct AddProcedureItemSheet<Picker: ProcedureItemPicking>: View {
    @Bindable var picker: Picker

    var body: some View {
        SheetList(
            "Add item", identifier: "addItem", searchText: $picker.searchText,
            emptyText: picker.addItemEmptyText, items: picker.addableProducts
        ) { product in
            ListRow(
                product.name, caption: picker.addCaption(for: product),
                captionTone: picker.addCaptionTone(for: product)
            ) {
                IconButton(.plus, label: "Add \(product.name)", variant: .outline, size: .small) {
                    picker.add(product)
                }
                .accessibilityIdentifier("addItem.row[\(product.id.uuidString.lowercased())].add")
            }
        }
        .task { await picker.loadProducts() }
        .onChange(of: picker.outOfStockProductID) { _, productID in
            guard productID != nil else { return }
            AccessibilityNotification.Announcement("Out of stock").post()
        }
    }
}
