import SwiftUI

/// Activity (f8, f9), pushed from Home's bell: "Alerts · N", the open alerts in one card with a dot, a sentence, when
/// it opened and a chevron to what resolves it ("Nothing needs attention." when all is well); and History, every
/// stock change by day, where an admin opens the invoice a receipt came from (MS-131).
struct ActivityView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: ActivityViewModel
    @State private var history: ActivityHistoryViewModel
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeActivityViewModel(session: session))
        _history = State(initialValue: dependencies.makeActivityHistoryViewModel(session: session, productID: nil))
    }

    var body: some View {
        content
            .pushedScreen(title: "Activity", identifier: "activity")
            .reloadOnReturn { await reload() }
            .navigationDestination(for: ActivityRoute.self) { route in
                switch route {
                case .product(let productID):
                    ProductDetailView(productID: productID, session: session, dependencies: dependencies)
                case .invoice(let invoiceID):
                    InvoiceView(invoiceID: invoiceID, session: session, dependencies: dependencies)
                }
            }
    }

    @ViewBuilder private var content: some View {
        SegmentedControl(selection: $viewModel.segment, options: viewModel.segmentOptions)
            .accessibilityIdentifier("activity.seg")
        switch viewModel.segment {
        case .alerts:
            alerts
        case .history:
            ActivityHistoryList(viewModel: history, onOpenInvoice: openInvoice)
        }
    }

    @ViewBuilder private var alerts: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.state == .loading && viewModel.alerts.isEmpty {
            ListCard {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("activity.loading")
        } else if viewModel.alerts.isEmpty {
            EmptyStateView(ActivityViewModel.emptyText)
        } else {
            ListCard {
                ForEach(viewModel.alerts) { alert in
                    ActivityAlertRow(
                        sentence: viewModel.sentence(for: alert), when: viewModel.whenText(for: alert),
                        tone: viewModel.dotTone(for: alert), showsDivider: alert.id != viewModel.alerts.last?.id
                    ) {
                        open(alert)
                    }
                    .accessibilityIdentifier("activity.alert[\(alert.id.uuidString.lowercased())]")
                }
            }
        }
    }

    /// The alerts, which the segment's count reads, and History too while it shows; History loads on appear itself.
    private func reload() async {
        await viewModel.load()
        if viewModel.segment == .history {
            await history.load()
        }
    }

    /// A receipt's invoice, from History: as it was received, read-only, or its lines to review again after an Undo.
    private func openInvoice(_ invoiceID: UUID) {
        router.push(ActivityRoute.invoice(invoiceID))
    }

    /// A delivery opens on Review invoice for its invoice, over Receive delivery, where Back leads (MS-130); receiving
    /// is a write, so in read-only mode the sheet says why instead (MS-142).
    private func open(_ alert: ActivityAlert) {
        switch viewModel.destination(for: alert) {
        case .product(let productID):
            router.push(ActivityRoute.product(productID))
        case .delivery(let invoiceID):
            writeAccess.perform {
                router.push(HomeRoute.receive)
                if let invoiceID { router.push(ReceiveRoute.invoice(invoiceID)) }
            }
        case nil:
            break
        }
    }
}

#Preview("Activity") {
    NavigationStack {
        ActivityView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}
