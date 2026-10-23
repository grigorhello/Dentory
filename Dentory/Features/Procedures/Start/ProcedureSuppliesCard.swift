import SwiftUI

/// "Supplies for this procedure" (f13): a row per countable supply with its stepper and X, a row per bottle taken
/// new, and Add item at the bottom.
struct ProcedureSuppliesCard: View {
    @Bindable var viewModel: ProcedureStartViewModel

    var body: some View {
        ListCard {
            ListHeaderRow("Supplies for this procedure", trailing: "Qty")
            ForEach(viewModel.supplies) { supply in
                ProcedureSupplyRow(
                    productID: supply.id, name: supply.item.name, note: viewModel.warning(for: supply),
                    reference: supply.defaultQuantity, quantity: $viewModel[quantityOf: supply.id],
                    onRemove: { viewModel.remove(supply.id) }
                )
            }
            ForEach(viewModel.takenNew) { bottle in
                ProcedureTakenNewRow(productID: bottle.id, name: bottle.item.name) {
                    viewModel.toggleTakeNew(bottle.id)
                }
            }
            HStack {
                MSButton("Add item", icon: .plus, variant: .text, size: .small, action: viewModel.openAddItem)
                    .accessibilityIdentifier("procDetail.addItem")
                Spacer()
            }
            .padding(.vertical, Spacing.sm)
        }
    }
}
