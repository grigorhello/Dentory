import SwiftUI

/// "Review corrections" (Appendix C `reviewCount`): each corrected product with its location, "43 → 41"
/// and Undo, in a list that scrolls past 360 pt. Apply count writes them; Back to counting closes the sheet.
struct ReviewCountSheet: View {
    let viewModel: InventoryListViewModel
    @State private var listHeight: CGFloat = 0

    var body: some View {
        let corrections = viewModel.corrections
        MSSheet("Review corrections", identifier: "reviewCount") {
            ScrollView {
                ListCard {
                    if corrections.isEmpty {
                        Text("No corrections. All items confirmed at their current quantity.")
                            .textStyle(.caption12)
                            .foregroundStyle(Color.ms.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xl)
                            .accessibilityIdentifier("reviewCount.empty")
                    }
                    ForEach(corrections) { product in
                        ReviewCountRow(
                            product: product,
                            change: viewModel.correctionLine(for: product),
                            tone: viewModel.correctionTone(for: product),
                            showsDivider: product.id != corrections.last?.id
                        ) {
                            viewModel.undoCorrection(product)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    listHeight = height
                }
            }
            .frame(height: min(listHeight, PageLayout.sheetListHeight))
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("reviewCount.list")
            if let error = viewModel.countError {
                Notice(error.userMessage, tone: .danger)
                    .accessibilityIdentifier("reviewCount.error")
            }
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    viewModel.applyTitle, icon: .check, isFullWidth: true, isLoading: viewModel.isApplyingCount,
                    isDisabled: corrections.isEmpty, action: apply
                )
                .accessibilityIdentifier("reviewCount.apply")
                MSButton("Back to counting", variant: .text, isFullWidth: true, action: viewModel.closeCountSheet)
                    .accessibilityIdentifier("reviewCount.back")
            }
        }
    }

    private func apply() {
        Task { await viewModel.applyCount() }
    }
}

#Preview("Review corrections") {
    let viewModel = AppDependencies.preview().makeInventoryListViewModel(session: .demo)
    Color.ms.canvas
        .msSheet(isPresented: .constant(true)) {
            ReviewCountSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.load()
            viewModel.startCount()
            viewModel.setCount(52, for: ProductSummary.demo[0])
            viewModel.setCount(3, for: ProductSummary.demo[1])
        }
}
