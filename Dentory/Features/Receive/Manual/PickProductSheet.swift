import SwiftUI

/// Choose product (Appendix C `pickProduct`): the title with New, the search, and a 360 pt list of the clinic's
/// products with their stock and a check on the chosen one. A tap chooses the product and closes the sheet; New puts
/// New product in the list's place.
struct PickProductSheet: View {
    @Bindable var viewModel: ManualReceiveViewModel

    var body: some View {
        SheetList(
            "Choose product", identifier: "pickProduct", searchText: $viewModel.searchText,
            emptyText: viewModel.pickEmptyText, items: viewModel.pickableProducts
        ) { product in
            PickProductRow(
                product: product, caption: viewModel.stockLine(for: product), isChosen: viewModel.isChosen(product)
            ) {
                viewModel.choose(product)
            }
        } action: {
            MSButton("New", icon: .plus, variant: .text, size: .small, action: viewModel.createProduct)
                .accessibilityIdentifier("pickProduct.new")
        }
        .task { await viewModel.load() }
    }
}
