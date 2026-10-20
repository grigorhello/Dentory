import SwiftUI

/// "DEFAULT SUPPLIES" (f15): a row per supply in the template's order, "No supplies yet." for a new one, and Add item
/// at the bottom of the card.
struct ProcedureDefaultsSection: View {
    @Bindable var viewModel: ProcedureEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow("Default supplies")
                .accessibilityAddTraits(.isHeader)
            ListCard {
                ForEach(viewModel.items) { item in
                    ProcedureDefaultRow(item: item, quantity: $viewModel[quantityOf: item.id]) {
                        viewModel.remove(item.id)
                    }
                }
                if viewModel.items.isEmpty {
                    Text(ProcedureEditViewModel.emptyText)
                        .textStyle(.caption12)
                        .foregroundStyle(Color.ms.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.lg)
                        .accessibilityIdentifier("procEdit.empty")
                }
                HStack {
                    MSButton("Add item", icon: .plus, variant: .text, size: .small, action: viewModel.openAddItem)
                        .accessibilityIdentifier("procEdit.addItem")
                    Spacer()
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }
}
