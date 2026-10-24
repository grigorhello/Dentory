import SwiftUI

/// Count mode's rows in one card (f18): the name, "est. 54 cartridges · location" (or "Count unopened only"),
/// and −/+ around the estimate; a corrected value turns blue. Rows do not open Product detail while counting.
struct InventoryCountRows: View {
    @Bindable var viewModel: InventoryListViewModel

    var body: some View {
        let rows = viewModel.visibleProducts
        ListCard {
            LazyVStack(spacing: 0) {
                ForEach(rows) { product in
                    InventoryCountRow(
                        product: product,
                        caption: viewModel.countLine(for: product),
                        isCorrected: viewModel.isCorrected(product),
                        showsDivider: product.id != rows.last?.id,
                        value: $viewModel[countOf: product]
                    )
                }
            }
        }
    }
}

#Preview("Count rows") {
    let viewModel = AppDependencies.preview().makeInventoryListViewModel(session: .demo)
    InventoryCountRows(viewModel: viewModel)
        .padding(Spacing.page)
        .background(Color.ms.canvas)
        .task {
            await viewModel.load()
            viewModel.startCount()
            viewModel.setCount(52, for: ProductSummary.demo[0])
        }
}
