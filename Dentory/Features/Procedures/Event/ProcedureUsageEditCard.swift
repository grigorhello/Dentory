import SwiftUI

/// "Supplies used" while editing: a row per countable supply with its stepper (blue and "Recorded 2" when it differs
/// from the record) and X, a row per bottle taken new, and Add item at the bottom.
struct ProcedureUsageEditCard: View {
    @Bindable var viewModel: ProcedureEventViewModel

    var body: some View {
        ListCard {
            ListHeaderRow("Supplies used", trailing: "Used")
            ForEach(viewModel.supplies) { supply in
                ProcedureSupplyRow(
                    productID: supply.id, name: supply.item.name, note: viewModel.note(for: supply),
                    reference: supply.recorded, quantity: $viewModel[quantityOf: supply.id],
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
