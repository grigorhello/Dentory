import SwiftUI

/// Expiring soon (f27 Admin, f28 Staff), pushed from Home's Expiring soon and At risk tiles: the 30 / 60 / 90 days
/// segments, pinned under the title, the summary, a card per batch with View product and the admin's Mark disposed,
/// and the empty state.
struct ExpiringView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: ExpiringViewModel
    let session: Session

    init(window: Int?, session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeExpiringViewModel(window: window, session: session))
    }

    var body: some View {
        content
            .pushedScreen(title: "Expiring soon", identifier: "expiring", pinned: {
                SegmentedControl(selection: $viewModel.window, options: viewModel.windowOptions)
                    .accessibilityIdentifier("expiring.seg")
            })
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: ExpiringRoute.self) { route in
                switch route {
                case .product(let productID):
                    ProductDetailView(productID: productID, session: session, dependencies: dependencies)
                }
            }
            .onChange(of: viewModel.message) { _, message in
                guard let message else { return }
                dependencies.toasts.show(message.title, detail: message.detail, undo: undo(for: message))
                viewModel.clearMessage()
            }
            .onChange(of: viewModel.generalError) { _, error in
                guard let error else { return }
                dependencies.toasts.show(error.userMessage)
                viewModel.clearGeneralError()
            }
            .msSheet(item: $viewModel.disposing) { batch in
                DisposeBatchSheet(
                    viewModel: viewModel.makeDisposeViewModel(for: batch), onKeep: viewModel.keep,
                    onDisposed: disposed
                )
            }
    }

    @ViewBuilder private var content: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.state == .loading && viewModel.list == nil {
            VStack(spacing: Spacing.md) {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("expiring.loading")
        } else if viewModel.batches.isEmpty {
            EmptyStateView(ExpiringViewModel.emptyText)
        } else {
            if let summary = viewModel.summary {
                Text(summary)
                    .textStyle(.body16)
                    .foregroundStyle(Color.ms.textBody)
                    .accessibilityIdentifier("expiring.summary")
            }
            ForEach(viewModel.batches) { batch in
                ExpiringCard(
                    batch: batch, line: viewModel.line(for: batch), daysText: viewModel.daysText(for: batch),
                    daysTone: viewModel.daysTone(for: batch), valueText: viewModel.valueText(for: batch),
                    showsDispose: viewModel.isAdmin,
                    onView: { router.push(ExpiringRoute.product(batch.productID)) },
                    onDispose: { writeAccess.perform { viewModel.askToDispose(batch) } }
                )
            }
        }
    }

    private func disposed(_ result: DisposeBatchViewModel.Disposed) {
        Task { await viewModel.disposed(result) }
    }

    private func undo(for message: ExpiringViewModel.Message) -> (@MainActor () -> Void)? {
        guard let actionID = message.undoActionID else { return nil }
        return { Task { await viewModel.undoDisposal(actionID) } }
    }
}

#Preview("Expiring soon · Admin") {
    NavigationStack {
        ExpiringView(window: nil, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}

#Preview("Expiring soon · Staff") {
    NavigationStack {
        ExpiringView(window: 90, session: .demo(role: .staff), dependencies: .preview(role: .staff))
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo(role: .staff))
}
