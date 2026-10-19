import SwiftUI

/// The sheet Product detail is showing (Appendix C `newProduct` in edit mode, `deleteProduct`, `adjust`, `batch`),
/// with what each one does when it closes: a toast, a reload, or leaving the screen after Delete.
struct ProductDetailSheet: View {
    @Environment(\.appDependencies) private var dependencies
    let sheet: ProductDetailViewModel.Sheet
    let viewModel: ProductDetailViewModel
    let session: Session

    var body: some View {
        switch sheet {
        case .edit:
            if let detail = viewModel.detail {
                ProductFormSheet(mode: .edit(detail), session: session, dependencies: dependencies) { _ in
                    dependencies.toasts.show("Changes saved")
                    Task { await viewModel.productSaved() }
                }
            }
        case .delete:
            DeleteProductSheet(
                title: viewModel.deleteTitle, message: viewModel.deleteMessage,
                isDeleting: viewModel.isSubmitting,
                onDelete: { Task { await viewModel.deleteProduct() } },
                onKeep: viewModel.keepProduct
            )
        case .adjust:
            if let adjustViewModel = viewModel.makeAdjustInventoryViewModel() {
                AdjustInventorySheet(viewModel: adjustViewModel) { saved in
                    Task { await viewModel.adjustmentSaved(saved) }
                }
            }
        case .addExpiry, .editBatch:
            if let batchViewModel = viewModel.makeBatchViewModel(for: sheet) {
                BatchSheet(viewModel: batchViewModel) { saved in
                    dependencies.toasts.show(saved.title, detail: saved.detail)
                    Task { await viewModel.batchSaved() }
                }
            }
        }
    }
}
