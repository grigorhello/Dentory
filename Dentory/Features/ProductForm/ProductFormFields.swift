import SwiftUI

/// The fields of the New / Edit product sheet in the order of Appendix C: the notice quoting an invoice line (MS-130),
/// name, category, units with the pack question and its sentence, the Multi-use switch (G1), the stock levels,
/// supplier and location.
struct ProductFormFields: View {
    @Bindable var viewModel: ProductFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let notice = viewModel.invoiceNotice {
                Notice(notice, identifier: "newProduct.fromInvoice")
            }
            MSTextField(
                "Name", text: $viewModel.name, identifier: "newProduct.name",
                placeholder: "As written on the box", error: viewModel.nameError
            )
            MSPicker(
                "Category", selection: $viewModel.category, options: viewModel.categoryChoices,
                error: viewModel.isNamingNewCategory ? nil : viewModel.categoryError, title: viewModel.categoryTitle
            )
            .accessibilityIdentifier("newProduct.category")
            if viewModel.isNamingNewCategory {
                MSTextField(
                    "New category", text: $viewModel.newCategoryName, identifier: "newProduct.newCategory",
                    placeholder: "e.g. Orthodontics", error: viewModel.categoryError
                )
            }
            units
            tracking
            levels
            MSTextField(
                "Supplier", text: $viewModel.supplier, identifier: "newProduct.supplier", placeholder: "Optional"
            )
            MSTextField(
                "Location", text: $viewModel.location, identifier: "newProduct.location", placeholder: "Optional"
            )
            if viewModel.showsReceivingHint {
                Text("Quantity, expiry and lot are entered on the receiving form.")
                    .textStyle(.caption12)
                    .foregroundStyle(Color.ms.textSecondary)
                    .accessibilityIdentifier("newProduct.receivingHint")
            }
        }
    }

    private var units: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow("Units")
                .accessibilityAddTraits(.isHeader)
            FieldRow {
                MSTextField(
                    "Counted in", text: $viewModel.unit, identifier: "newProduct.unit",
                    placeholder: "e.g. cartridges", error: viewModel.unitError
                )
                MSTextField(
                    "Received as", text: $viewModel.packUnit, identifier: "newProduct.packUnit", placeholder: "e.g. box"
                )
            }
            if let question = viewModel.packQuestion {
                MSTextField(
                    question, text: $viewModel.packSizeText, identifier: "newProduct.packSize", placeholder: "e.g. 50",
                    hint: viewModel.packSentence, error: viewModel.packSizeError, keyboard: .numberPad
                )
            }
        }
    }

    private var tracking: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            MSToggle(
                "Multi-use (bottle, syringe, kit)",
                isOn: Binding(get: { viewModel.isMultiUse }, set: { viewModel.setMultiUse($0) })
            )
            .accessibilityIdentifier("newProduct.multiUse")
            if let error = viewModel.trackingError {
                Text(error)
                    .textStyle(.caption12)
                    .foregroundStyle(Color.ms.danger)
                    .accessibilityIdentifier("newProduct.trackingError")
            } else {
                Text(viewModel.trackingCaption).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
            }
        }
    }

    private var levels: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow("Stock levels")
                .accessibilityAddTraits(.isHeader)
            FieldRow {
                MSTextField(
                    "Minimum", text: $viewModel.minimumText, identifier: "newProduct.minimum",
                    placeholder: "Alert below", error: viewModel.minimumError, keyboard: .decimalPad
                )
                MSTextField(
                    "Target", text: $viewModel.targetText, identifier: "newProduct.target",
                    placeholder: "Reorder up to", error: viewModel.targetError, keyboard: .decimalPad
                )
            }
        }
    }
}
