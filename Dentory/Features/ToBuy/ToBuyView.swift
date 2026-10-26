import SwiftUI

/// To buy (f25 Admin, f26 Staff): the segments, pinned under the title while the lines scroll, the selection bar and
/// Mark N as ordered for Admin, the lines with their steppers, and Add item. A shopping list: nothing here places an
/// order. The list reloads whenever a tab is chosen and after any stock change, so the tab's badge keeps the count of
/// lines still to buy.
struct ToBuyView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: ToBuyViewModel

    init(session: Session, dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeToBuyViewModel(session: session))
    }

    var body: some View {
        content
            .rootScreen(title: "To buy", identifier: "order.header") {
                EmptyView()
            } pinned: {
                SegmentedControl(selection: $viewModel.segment, options: viewModel.segmentOptions)
                    .accessibilityIdentifier("order.seg")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.showsMarkOrdered {
                    // The tab stays alive behind the others: toasts on them float above this bar only while it shows.
                    PinnedPrimaryBar(reportsHeight: router.selectedTab == .toBuy) {
                        MSButton(
                            viewModel.markOrderedTitle, isFullWidth: true, isLoading: viewModel.isMarking,
                            isDisabled: viewModel.selectedItems.isEmpty, action: markOrdered
                        )
                        .accessibilityIdentifier("order.markOrdered")
                    }
                }
            }
            .reloadOnReturn { await viewModel.load() }
            .onChange(of: router.selectedTab) { reload() }
            .onChange(of: dependencies.writes.appliedWrites) { reload() }
            .onChange(of: viewModel.toBuyCount, initial: true) { _, count in
                router.toBuyCount = count
            }
            .onChange(of: writeAccess.canWrite, initial: true) { _, canWrite in
                viewModel.isReadOnly = !canWrite
            }
            .onChange(of: viewModel.refusedChanges) {
                writeAccess.showReadOnly()
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
            .msSheet(item: $viewModel.sheet) { _ in
                AddToBuySheet(viewModel: viewModel)
            }
    }

    @ViewBuilder private var content: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.state == .loading && viewModel.items.isEmpty {
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("order.loading")
        } else {
            if viewModel.showsSelection {
                ToBuySelectionBar(viewModel: viewModel)
            }
            if viewModel.rows.isEmpty {
                EmptyStateView(ToBuyViewModel.emptyText)
            } else {
                ToBuyRows(viewModel: viewModel)
            }
            if viewModel.segment == .toBuy {
                MSButton("Add item", icon: .plus, variant: .text, size: .small) {
                    writeAccess.perform(viewModel.openAddItem)
                }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("order.add")
            }
        }
    }

    private func undo(for message: ToBuyViewModel.Message) -> (@MainActor () -> Void)? {
        guard let itemID = message.undoItemID else { return nil }
        return { Task { await viewModel.undoAdd(itemID) } }
    }

    /// Add item, Mark as ordered, the steppers and Remove open the read-only sheet instead in read-only mode (MS-142).
    private func markOrdered() {
        writeAccess.perform { Task { await viewModel.markOrdered() } }
    }

    private func reload() {
        Task { await viewModel.load() }
    }
}

#Preview("To buy · Admin") {
    NavigationStack {
        ToBuyView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .toBuy))
    .environment(\.session, Session.demo)
}

#Preview("To buy · Staff") {
    NavigationStack {
        ToBuyView(session: .demo(role: .staff), dependencies: .preview(role: .staff))
    }
    .environment(AppRouter(selectedTab: .toBuy))
    .environment(\.session, Session.demo(role: .staff))
}
