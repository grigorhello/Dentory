import SwiftUI

/// History (f9): the chips, then the entries in one card per day under its eyebrow. A chip reloads the list. Days and
/// rows are built as they scroll in, and the next page loads when the row after the last one, shown while more may
/// follow, scrolls in. Its own stack keeps f9's gaps whether it sits under Activity's segments or fills a product's
/// History alone. On an admin's Activity a receipt opens the invoice it came from (MS-131).
struct ActivityHistoryList: View {
    @Bindable var viewModel: ActivityHistoryViewModel
    /// Opens a receipt's invoice; only rows the view model names an invoice for call it.
    var onOpenInvoice: (UUID) -> Void = { _ in }

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
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(viewModel.days) { day in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow(day.title)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("activity.day")
                        ListCard {
                            LazyVStack(spacing: 0) {
                                ForEach(day.entries) { entry in
                                    row(entry, isLastOfDay: entry.id == day.entries.last?.id)
                                }
                            }
                        }
                    }
                }
                if viewModel.hasMore {
                    nextPage
                }
            }
        }
    }

    /// Asks for the next page as it scrolls in, again after each page while more may follow, and again on its next
    /// appearance after a failure.
    private var nextPage: some View {
        ProgressView()
            .tint(Color.ms.primary)
            .frame(maxWidth: .infinity, minHeight: ControlHeight.hitTarget)
            .accessibilityIdentifier("activity.history.more")
            .task(id: viewModel.entries.count) { await viewModel.loadMore() }
    }

    private func row(_ entry: ActivityHistoryEntry, isLastOfDay: Bool) -> some View {
        ActivityHistoryRow(
            subject: entry.subject, reason: viewModel.reasonText(for: entry), who: viewModel.whoText(for: entry),
            delta: viewModel.deltaText(for: entry), tone: viewModel.deltaTone(for: entry), showsDivider: !isLastOfDay,
            open: viewModel.invoiceID(for: entry).map { invoiceID in { onOpenInvoice(invoiceID) } }
        )
        .accessibilityIdentifier("activity.row[\(entry.id.uuidString.lowercased())]")
    }
}
