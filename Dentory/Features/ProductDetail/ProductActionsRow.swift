import SwiftUI

/// Adjust beside Add to buy in equal halves (f20); when a label does not fit its half, Adjust keeps its own
/// width and the primary button takes the rest, and on a narrower screen the two stack. Add to buy opens the
/// To buy tab once the product is on the list. Adjust and Add to buy open the read-only sheet instead in
/// read-only mode (MS-142); "On To buy" only goes to the list.
struct ProductActionsRow: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    let viewModel: ProductDetailViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            EqualWidthHStack(spacing: Spacing.md) {
                adjustButton(isFullWidth: true)
                addToBuyButton
            }
            HStack(spacing: Spacing.md) {
                adjustButton(isFullWidth: false)
                addToBuyButton
            }
            VStack(spacing: Spacing.md) {
                adjustButton(isFullWidth: true)
                addToBuyButton
            }
        }
    }

    private func adjustButton(isFullWidth: Bool) -> some View {
        MSButton("Adjust", icon: .slidersHorizontal, variant: .tertiary, isFullWidth: isFullWidth) {
            writeAccess.perform(viewModel.openAdjust)
        }
        .accessibilityIdentifier("product.adjust")
    }

    private var addToBuyButton: some View {
        MSButton(
            viewModel.addToBuyTitle, icon: .shoppingCart, isFullWidth: true, isLoading: viewModel.isSubmitting,
            action: addToBuy
        )
        .accessibilityIdentifier("product.addToBuy")
    }

    private func addToBuy() {
        if viewModel.isOnToBuy {
            router.select(.toBuy)
        } else {
            writeAccess.perform { Task { await viewModel.addToBuy() } }
        }
    }
}
