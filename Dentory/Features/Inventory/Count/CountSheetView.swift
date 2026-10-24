import SwiftUI

/// The sheet count mode presents: Review corrections, or Discard this count? when Cancel finds changes.
struct CountSheetView: View {
    let sheet: InventoryListViewModel.CountSheet
    let viewModel: InventoryListViewModel

    var body: some View {
        switch sheet {
        case .review:
            ReviewCountSheet(viewModel: viewModel)
        case .discard:
            DiscardCountSheet(
                message: viewModel.discardMessage, onDiscard: viewModel.discardCount, onKeep: viewModel.closeCountSheet
            )
        }
    }
}
