import SwiftUI

/// "History · tap to edit usage" (f11): every past procedure, newest first, each opening its usage. The next
/// page loads when the last row shows.
struct ProcedureHistorySection: View {
    let viewModel: ProceduresViewModel

    var body: some View {
        let events = viewModel.history
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow("History · tap to edit usage")
                .accessibilityAddTraits(.isHeader)
            ListCard {
                LazyVStack(spacing: 0) {
                    ForEach(events) { event in
                        NavigationLink(value: ProcedureRoute.event(event.id)) {
                            ListRow(
                                event.name,
                                caption: viewModel.historyLine(for: event),
                                navigates: true,
                                showsDivider: event.id != events.last?.id
                            ) {
                                Text(viewModel.itemsText(event.itemCount))
                                    .textStyle(.caption12)
                                    .foregroundStyle(Color.ms.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("proc.history[\(event.id.uuidString.lowercased())]")
                        .onAppear { loadMoreIfLast(event) }
                    }
                }
            }
        }
    }

    private func loadMoreIfLast(_ event: ProcedureEventSummary) {
        guard event.id == viewModel.history.last?.id else { return }
        Task { await viewModel.loadMoreHistory() }
    }
}
