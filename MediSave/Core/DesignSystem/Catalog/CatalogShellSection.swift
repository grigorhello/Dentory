#if DEBUG
import SwiftUI

/// The shell overlays (MS-103): a demo sheet, a list sheet and a toast with Undo.
struct CatalogShellSection: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var isSheetPresented = false
    @State private var isListPresented = false
    @State private var searchText = ""
    @State private var quantity = "52"

    private struct Item: Identifiable {
        let id: Int
        let name: String
    }

    private let items = (1...12).map { Item(id: $0, name: "Product \($0)") }

    var body: some View {
        CatalogSection("Shell: sheet and toast") {
            HStack(spacing: Spacing.md) {
                MSButton("Open sheet", variant: .tertiary, size: .small) { isSheetPresented = true }
                    .accessibilityIdentifier("catalog.shell.sheet")
                MSButton("Open list", variant: .tertiary, size: .small) { isListPresented = true }
                    .accessibilityIdentifier("catalog.shell.sheetList")
                MSButton("Show toast", variant: .tertiary, size: .small) {
                    dependencies.toasts.show("Adjustment saved", detail: "Septocaine 4% · 54 → 52") {
                        dependencies.toasts.show("Adjustment undone")
                    }
                }
                .accessibilityIdentifier("catalog.shell.toast")
            }
            CatalogCaption("Sheet: handle, 20 pt radius, fitted height, swipe or tap outside to close.")
            CatalogCaption("Toast: 3.2 s, Undo.")
            PinnedPrimaryBar(caption: "Resolve every line to continue.") {
                MSButton("Confirm & receive", isFullWidth: true, isDisabled: true) {}
            }
            OfflineBanner()
        }
        .msSheet(isPresented: $isSheetPresented) {
            MSSheet(
                "Adjust inventory",
                caption: "System estimate 54 cartridges. A reason is recorded in history.",
                identifier: "adjust"
            ) {
                MSTextField("Actual quantity", text: $quantity, suffix: "cartridges", keyboard: .numberPad)
            } primary: {
                MSButton("Save adjustment", isFullWidth: true) { isSheetPresented = false }
            }
        }
        .msSheet(isPresented: $isListPresented) {
            SheetList(
                "Choose product", identifier: "pickProduct", searchText: $searchText, items: visibleItems
            ) { item in
                ListRow(item.name, caption: "12 in stock", showsDivider: item.id != visibleItems.last?.id) {
                    IconButton(.plus, label: "Add \(item.name)", variant: .outline, size: .small) {
                        isListPresented = false
                    }
                }
            }
        }
    }

    private var visibleItems: [Item] {
        items.filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
    }
}
#endif
