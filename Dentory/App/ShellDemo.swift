#if DEBUG
import SwiftUI

/// Routes of the Debug-only shell demo reached from a tab placeholder.
enum ShellDemoRoute: Hashable {
    case pushed
}

/// Exercises the pushed screen, the pinned bar, `MSSheet`, `SheetList` and the toast (MS-103 acceptance).
struct ShellDemoPushedView: View {
    @Environment(\.appDependencies) private var dependencies
    let route: ShellDemoRoute
    @State private var sheet: DemoSheet?
    @State private var searchText = ""
    @State private var quantity = "52"
    /// `-shellDemo sheet|list|toast` as a launch argument opens that overlay on appear, for screenshots.
    private let launchDemo = UserDefaults.standard.string(forKey: "shellDemo")

    private enum DemoSheet: String, Identifiable {
        case adjust, pick
        var id: String { rawValue }
    }

    private struct DemoProduct: Identifiable {
        let id: Int
        let name: String
        let stock: String
    }

    private let products = [
        DemoProduct(id: 1, name: "Septocaine 4% 1:100,000", stock: "54 cartridges in stock"),
        DemoProduct(id: 2, name: "Needle 27g short", stock: "120 needles in stock"),
        DemoProduct(id: 3, name: "Nitrile gloves M", stock: "6 boxes in stock"),
        DemoProduct(id: 4, name: "Rubber dam latex-free", stock: "0 in stock"),
        DemoProduct(id: 5, name: "Endo file kit #15-40", stock: "1 kit in stock"),
        DemoProduct(id: 6, name: "Gutta percha F2", stock: "3 packs in stock"),
        DemoProduct(id: 7, name: "Paper points", stock: "4 packs in stock"),
        DemoProduct(id: 8, name: "Composite A2", stock: "2 syringes in stock")
    ]

    var body: some View {
        ListCard {
            ListRow("Open a sheet", caption: "Adjust inventory", navigates: false) {
                MSButton("Adjust", variant: .tertiary, size: .small) { sheet = .adjust }
                    .accessibilityIdentifier("shell.demo.sheet")
            }
            ListRow("Open a list sheet", caption: "Choose product, 360 pt list") {
                MSButton("Choose", variant: .tertiary, size: .small) { sheet = .pick }
                    .accessibilityIdentifier("shell.demo.sheetList")
            }
            ListRow("Show a toast", caption: "3.2 s, with Undo") {
                MSButton("Toast", variant: .tertiary, size: .small, action: showToast)
                    .accessibilityIdentifier("shell.demo.toast")
            }
            ListRow("Admin only row", caption: "Hidden for Staff", showsDivider: false)
                .adminOnly()
        }
        .pushedScreen(
            title: "Shell demo",
            subtitle: "Patterson Dental · INV-10092 · $449.00",
            identifier: "shell.demo",
            action: .init(title: "Edit", identifier: "shell.demo.edit") {
                dependencies.toasts.show("Edit tapped")
            }
        )
        .pinnedPrimaryBar(caption: "Resolve every line to continue.") {
            MSButton("Confirm & receive", isFullWidth: true) {
                dependencies.toasts.show("Invoice received", detail: "4 products updated")
            }
            .accessibilityIdentifier("shell.demo.primary")
        }
        .onAppear {
            switch launchDemo {
            case "sheet": sheet = .adjust
            case "list": sheet = .pick
            case "toast": showToast()
            default: break
            }
        }
        .msSheet(item: $sheet) { which in
            switch which {
            case .adjust:
                MSSheet(
                    "Adjust inventory",
                    caption: "System estimate 54 cartridges. A reason is recorded in history.",
                    identifier: "adjust"
                ) {
                    MSTextField("Actual quantity", text: $quantity, suffix: "cartridges", keyboard: .numberPad)
                        .accessibilityIdentifier("adjust.quantity")
                } primary: {
                    MSButton("Save adjustment", isFullWidth: true) {
                        sheet = nil
                        dependencies.toasts.show("Adjustment saved", detail: "Septocaine 4% · 54 → \(quantity)") {}
                    }
                    .accessibilityIdentifier("adjust.save")
                }
            case .pick:
                SheetList(
                    "Choose product", identifier: "pickProduct", searchText: $searchText, items: visibleProducts
                ) { product in
                    let isLast = product.id == visibleProducts.last?.id
                    ListRow(product.name, caption: product.stock, showsDivider: !isLast) {
                        IconButton(.plus, label: "Add \(product.name)", variant: .outline, size: .small) { sheet = nil }
                    }
                } action: {
                    Button("New") { sheet = nil }
                        .buttonStyle(.ms(.text, size: .small))
                        .accessibilityIdentifier("pickProduct.new")
                }
            }
        }
    }

    private func showToast() {
        dependencies.toasts.show("Adjustment saved", detail: "Septocaine 4% · 54 → 52") {
            dependencies.toasts.show("Adjustment undone")
        }
    }

    private var visibleProducts: [DemoProduct] {
        products.filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
    }
}

#Preview("Shell demo") {
    NavigationStack {
        ShellDemoPushedView(route: .pushed)
    }
}
#endif
