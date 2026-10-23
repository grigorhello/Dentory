import SwiftUI

/// Invoices (f35), pushed from Billing: the clinic's invoices with their date, amount and status, newest first, or
/// "No invoices yet" with when the first comes. No row links anywhere (MS-100 D18).
struct InvoicesView: View {
    @State private var viewModel: InvoicesViewModel

    init(session: Session, trialEndsAt: Date?, dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeInvoicesViewModel(session: session, trialEndsAt: trialEndsAt))
    }

    var body: some View {
        content
            .pushedScreen(title: "Invoices", identifier: "invoices")
            .reloadOnReturn { await viewModel.load() }
    }

    @ViewBuilder private var content: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.invoices == nil {
            ListCard {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("invoices.loading")
        } else if viewModel.rows.isEmpty {
            EmptyStateView(viewModel.emptyCaption, title: InvoicesViewModel.emptyTitle)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("invoices.empty")
        } else {
            ListCard {
                ForEach(viewModel.rows) { row in
                    ListRow(row.date, caption: row.number, showsDivider: row.id != viewModel.rows.last?.id) {
                        HStack(spacing: Spacing.sm) {
                            ListRowValue(row.amount)
                            StatusBadge(row.status, tone: row.tone, size: .small)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("invoices.row[\(row.id.uuidString.lowercased())]")
                }
            }
        }
    }
}

#Preview("Invoices") {
    NavigationStack {
        InvoicesView(session: .demo, trialEndsAt: BillingSummary.demoTrialEnd, dependencies: .preview())
    }
}
