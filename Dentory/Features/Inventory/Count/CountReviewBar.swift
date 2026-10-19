import SwiftUI

/// Count mode's pinned primary (f18): "Review count", disabled until a quantity changed, then
/// "Review · 2 corrections". The tab bar stays while counting, so the bar sits on top of it.
struct CountReviewBar: View {
    @Environment(\.tabBarInset) private var tabBarInset
    let viewModel: InventoryListViewModel

    var body: some View {
        PinnedPrimaryBar {
            MSButton(
                viewModel.reviewTitle, icon: .check, isFullWidth: true, isDisabled: viewModel.correctionCount == 0,
                action: viewModel.reviewCount
            )
            .accessibilityIdentifier("inv.count.review")
        }
        .padding(.bottom, tabBarInset)
    }
}
