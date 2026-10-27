import SwiftUI

/// History's chips (f9), pinned under the header while the days scroll (f09-2). The list loads as they appear and
/// again whenever a chip is chosen.
struct ActivityHistoryFilters: View {
    @Bindable var viewModel: ActivityHistoryViewModel

    var body: some View {
        FilterChipRow(
            selection: $viewModel.filter,
            options: ActivityHistoryFilter.allCases.map { SegmentOption($0, label: $0.rawValue) }
        )
        .padding(.horizontal, -Spacing.page)
        // The 36 pt chips sit 4 pt inside their 44 pt row; its last 4 pt reach into the strip under the pinned
        // controls, so the days are cut 4 pt under the chips (f09-2) and the chips keep their whole hit area.
        .padding(.bottom, -Spacing.xs)
        .accessibilityIdentifier("activity.filter")
        .task(id: viewModel.filter) { await viewModel.load() }
    }
}
