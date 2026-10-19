import SwiftUI

/// The Inventory header's action: Count stock while browsing (f16), Cancel while counting (f18).
struct InventoryHeaderAction: View {
    let viewModel: InventoryListViewModel

    var body: some View {
        if viewModel.isCounting {
            MSButton("Cancel", variant: .text, size: .small, action: viewModel.cancelCount)
                .accessibilityIdentifier("inv.count.cancel")
        } else {
            MSButton(
                "Count stock", icon: .clipboardList, variant: .tertiary, size: .small, action: viewModel.startCount
            )
            .accessibilityIdentifier("inv.countStock")
        }
    }
}
