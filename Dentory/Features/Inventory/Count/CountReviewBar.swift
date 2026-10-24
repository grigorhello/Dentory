import SwiftUI

/// Count mode's pinned primary (f18): "Review count", disabled until a quantity changed, then
/// "Review · 2 corrections". The tab bar stays while counting, so the bar sits on top of it. A count kept from before
/// the clinic turned read-only opens the read-only sheet instead of the review (MS-142).
struct CountReviewBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    let viewModel: InventoryListViewModel

    var body: some View {
        // The tab stays alive behind the others: toasts on them float above this bar only while it shows.
        PinnedPrimaryBar(reportsHeight: router.selectedTab == .inventory) {
            MSButton(
                viewModel.reviewTitle, icon: .check, isFullWidth: true, isDisabled: viewModel.correctionCount == 0,
                action: review
            )
            .accessibilityIdentifier("inv.count.review")
        }
    }

    private func review() {
        writeAccess.perform(viewModel.reviewCount)
    }
}
