import SwiftUI

/// "Add item" (Appendix C `addItem`): search, a 360 pt list of the products not on the list yet with the caption the
/// screen gives each ("40 needles in stock" on Adjust, then start; "Anesthetic · multi-use" on Edit procedure), and
/// + per row, which hands the product to the screen. What goes wrong is said inside the sheet, where it can be seen:
/// "Out of stock" on the row tapped, and a failed load in place of the list. The screen that opens it passes its own
/// view model's search, products and actions, as the shared rows and steppers take theirs.
struct AddProcedureItemSheet: View {
    @Binding var searchText: String
    /// The products not on the list yet that match the search, by name.
    let products: [ProductSummary]
    /// What the list says when nothing matches: empty while the products load, how to retry when they failed.
    let emptyText: String
    /// The product + found nothing unopened for: its row reads "Out of stock", and VoiceOver hears it.
    var outOfStockProductID: UUID?
    let caption: (ProductSummary) -> String?
    /// The caption's color: danger for "Out of stock", the secondary text color otherwise (nil).
    var captionTone: (ProductSummary) -> StatusTone? = { _ in nil }
    let onAdd: (ProductSummary) -> Void
    /// Loads the clinic's products when the sheet opens.
    let load: () async -> Void

    var body: some View {
        SheetList(
            "Add item", identifier: "addItem", searchText: $searchText, emptyText: emptyText, items: products
        ) { product in
            ListRow(product.name, caption: caption(product), captionTone: captionTone(product)) {
                IconButton(.plus, label: "Add \(product.name)", variant: .outline, size: .small) {
                    onAdd(product)
                }
                .accessibilityIdentifier("addItem.row[\(product.id.uuidString.lowercased())].add")
            }
        }
        .task { await load() }
        .onChange(of: outOfStockProductID) { _, productID in
            guard productID != nil else { return }
            AccessibilityNotification.Announcement("Out of stock").post()
        }
    }
}
