import SwiftUI

/// History (f9): the chips, then the entries in one card per day under its eyebrow. A chip reloads the list; the next
/// page loads when the last row shows. Its own stack keeps f9's gaps whether it sits under Activity's segments or
/// fills a product's History alone.
struct ActivityHistoryList: View {
    @Bindable var viewModel: ActivityHistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FilterChipRow(
                selection: $viewModel.filter,
                options: ActivityHistoryFilter.allCases.map { SegmentOption($0, label: $0.rawValue) }
            )
            .padding(.horizontal, -Spacing.page)
            .accessibilityIdentifier("activity.filter")
            .task(id: viewModel.filter) { await viewModel.load() }
            content
        }
    }

    @ViewBuilder private var content: some View {
        if case .failed(let error) = viewModel.state, viewModel.entries.isEmpty {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.entries.isEmpty && viewModel.state == .loading {
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("activity.history.loading")
        } else if viewModel.isEmpty {
            EmptyStateView(viewModel.emptyText)
        } else {
            ForEach(viewModel.days) { day in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Eyebrow(day.title)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("activity.day")
                    ListCard {
                        ForEach(day.entries) { entry in
                            row(entry, isLastOfDay: entry.id == day.entries.last?.id)
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: ActivityHistoryEntry, isLastOfDay: Bool) -> some View {
        ActivityHistoryRow(
            subject: entry.subject, reason: viewModel.reasonText(for: entry), who: viewModel.whoText(for: entry),
            delta: viewModel.deltaText(for: entry), tone: viewModel.deltaTone(for: entry), showsDivider: !isLastOfDay
        )
        .accessibilityIdentifier("activity.row[\(entry.id.uuidString.lowercased())]")
        .task {
            guard entry.id == viewModel.entries.last?.id else { return }
            await viewModel.loadMore()
        }
    }
}
