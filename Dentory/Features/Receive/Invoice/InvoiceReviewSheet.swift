import SwiftUI

/// The sheet over Review invoice's lines: Which product is this? (Appendix C `match`), whose tap matches the line, or
/// New product from the line (Appendix C `newProduct`, MS-117's sheet), whose Create and use for this line creates the
/// product and makes the line Created.
struct InvoiceReviewSheet: View {
    @Environment(\.appDependencies) private var dependencies
    let sheet: InvoiceReviewViewModel.Sheet
    let viewModel: InvoiceReviewViewModel
    let session: Session

    var body: some View {
        switch sheet {
        case .match(let line):
            InvoiceMatchSheet(line: line, session: session, dependencies: dependencies) { product in
                choose(product, for: line)
            }
        case .newProduct(let line):
            ProductFormSheet(
                mode: .invoiceLine(raw: line.raw, name: line.suggestedName ?? "", unit: line.suggestedUnit ?? ""),
                session: session, dependencies: dependencies
            ) { outcome in
                created(outcome, for: line)
            }
        }
    }

    /// A tap on Which product is this?: the line is Matched to the product.
    private func choose(_ product: ReceivableProduct, for line: InvoiceLine) {
        Task { await viewModel.choose(product.id, for: line) }
    }

    /// Create and use for this line: the line becomes the product just created.
    private func created(_ outcome: ProductFormViewModel.Outcome, for line: InvoiceLine) {
        guard case .created(let productID) = outcome else { return }
        Task { await viewModel.productCreated(productID, for: line) }
    }
}
