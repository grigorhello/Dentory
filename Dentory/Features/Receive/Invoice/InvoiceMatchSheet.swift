import SwiftUI

/// Which product is this? (Appendix C `match`): the line as read in monospace, the search and a 360 pt list of the
/// clinic's products with their category and stock. A tap picks the product and closes the sheet.
struct InvoiceMatchSheet: View {
    @State private var viewModel: InvoiceMatchViewModel
    let onPick: (ReceivableProduct) -> Void

    init(
        line: InvoiceLine, session: Session, dependencies: AppDependencies,
        onPick: @escaping (ReceivableProduct) -> Void
    ) {
        _viewModel = State(initialValue: dependencies.makeInvoiceMatchViewModel(line: line, session: session))
        self.onPick = onPick
    }

    var body: some View {
        SheetList(
            InvoiceMatchViewModel.title, identifier: "match", code: viewModel.line.raw,
            searchText: $viewModel.searchText, emptyText: viewModel.emptyText, items: viewModel.pickableProducts
        ) { product in
            Button {
                onPick(product)
            } label: {
                ListRow(product.name, caption: viewModel.caption(for: product), navigates: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("match.row[\(product.id.uuidString.lowercased())]")
        }
        .task { await viewModel.load() }
    }
}
