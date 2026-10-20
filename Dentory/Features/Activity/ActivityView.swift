import SwiftUI

/// Activity (f8), pushed from Home's bell: "Alerts · N" and History, the open alerts in one card with a dot, a
/// sentence, when it opened and a chevron to what resolves it, and "Nothing needs attention." when all is well.
struct ActivityView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var viewModel: ActivityViewModel
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeActivityViewModel(session: session))
    }

    var body: some View {
        content
            .pushedScreen(title: "Activity", identifier: "activity")
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: ActivityRoute.self) { route in
                switch route {
                case .product(let productID):
                    ProductDetailView(productID: productID, session: session, dependencies: dependencies)
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
            EmptyStateView(ActivityViewModel.historyText)
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

    private func open(_ alert: ActivityAlert) {
        switch viewModel.destination(for: alert) {
        case .product(let productID): router.push(ActivityRoute.product(productID))
        case .delivery: router.push(HomeRoute.receive)
        case nil: break
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
