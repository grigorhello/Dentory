import SwiftUI

/// One product's history, from Product detail's Show all (Appendix B `activity` with `productId`): History's chips and
/// days for that product alone, each procedure listed with the product's own quantity.
struct ActivityHistoryView: View {
    @State private var viewModel: ActivityHistoryViewModel
    let productName: String

    init(productID: UUID, productName: String, session: Session, dependencies: AppDependencies) {
        self.productName = productName
        _viewModel = State(
            initialValue: dependencies.makeActivityHistoryViewModel(session: session, productID: productID)
        )
    }

    var body: some View {
        ActivityHistoryList(viewModel: viewModel)
            .pushedScreen(title: "History", subtitle: productName, identifier: "activity")
    }
}

#Preview("History · one product") {
    NavigationStack {
        ActivityHistoryView(
            productID: ProductSummary.demo[0].id, productName: "Septocaine 4% 1:100,000", session: .demo,
            dependencies: .preview()
        )
    }
}
