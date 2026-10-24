import SwiftUI

/// The Inventory header's action: Count stock while browsing (f16), Cancel while counting (f18). In read-only mode
/// Count stock opens the read-only sheet instead (MS-142).
struct InventoryHeaderAction: View {
    @Environment(\.writeAccess) private var writeAccess
    let viewModel: InventoryListViewModel

    var body: some View {
        if viewModel.isCounting {
            MSButton("Cancel", variant: .text, size: .small, action: viewModel.cancelCount)
                .accessibilityIdentifier("inv.count.cancel")
        } else {
            MSButton("Count stock", icon: .clipboardList, variant: .tertiary, size: .small, action: startCount)
                .accessibilityIdentifier("inv.countStock")
        }
    }

    private func startCount() {
        writeAccess.perform(viewModel.startCount)
    }
}
