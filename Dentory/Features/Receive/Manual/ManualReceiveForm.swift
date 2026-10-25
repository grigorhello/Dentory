import SwiftUI

/// The fields of Receive manually in f24's order: the product, then the quantity beside the cost, then the lot beside
/// the expiry. The form owns the text fields' focus, so opening the expiry wheels can put the keyboard away first.
struct ManualReceiveForm: View {
    /// The text fields of the form.
    enum Field: Hashable {
        case quantity, cost, lot
    }

    @Bindable var viewModel: ManualReceiveViewModel
    @FocusState private var focus: Field?

    var body: some View {
        MSSelectField(
            "Product", value: viewModel.product?.name, caption: viewModel.product.map(viewModel.stockLine(for:)),
            placeholder: ManualReceiveViewModel.productPlaceholder, identifier: "manual.product",
            action: viewModel.openPicker
        )
        ManualReceiveAmountRow(viewModel: viewModel, focus: $focus)
        ManualReceiveBatchRow(viewModel: viewModel, focus: $focus)
    }
}
