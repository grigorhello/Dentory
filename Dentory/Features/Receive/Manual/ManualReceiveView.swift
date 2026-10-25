import SwiftUI

/// Receive manually (f24), Admin only, pushed from Receive delivery's "Receive manually" (MS-126): the product, chosen
/// on Choose product, the quantity and the cost in the unit it is received in, the lot and the expiry month, and
/// Receive pinned at the bottom, which lands on Inventory with the toast (PRD §6.5).
struct ManualReceiveView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: ManualReceiveViewModel
    let session: Session

    init(productID: UUID?, session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(
            initialValue: dependencies.makeManualReceiveViewModel(productID: productID, session: session)
        )
    }

    var body: some View {
        ManualReceiveForm(viewModel: viewModel)
            .pushedScreen(title: "Receive manually", identifier: "manual")
            .pinnedPrimaryBar {
                MSButton(
                    "Receive", isFullWidth: true, isLoading: viewModel.isReceiving,
                    isDisabled: !viewModel.canReceive, action: receive
                )
                .accessibilityIdentifier("manual.receive")
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.received) { _, received in openInventory(with: received) }
            .onChange(of: viewModel.message) { _, message in show(message) }
            .onChange(of: viewModel.generalError) { _, error in show(error) }
            .msSheet(item: $viewModel.sheet) { _ in
                ManualReceiveSheet(viewModel: viewModel, session: session)
            }
    }

    /// In read-only mode the sheet says why instead (MS-142).
    private func receive() {
        writeAccess.perform {
            Task { await viewModel.receive() }
        }
    }

    /// The delivery is in: Inventory at the root of its tab, with the toast (no Undo, PRD §7).
    private func openInventory(with received: ManualReceiveViewModel.Message?) {
        guard let received else { return }
        router.popToRoot(on: router.selectedTab)
        router.popToRoot(on: .inventory)
        router.selectedTab = .inventory
        dependencies.toasts.show(received.title, detail: received.detail)
    }

    private func show(_ message: ManualReceiveViewModel.Message?) {
        guard let message else { return }
        dependencies.toasts.show(message.title, detail: message.detail)
        viewModel.clearMessage()
    }

    /// A refused receipt, as a toast; what was typed stays (PRD §7 errors).
    private func show(_ error: AppError?) {
        guard let error else { return }
        dependencies.toasts.show(error.userMessage)
        viewModel.clearGeneralError()
    }
}

#Preview("Receive manually") {
    NavigationStack {
        ManualReceiveView(productID: nil, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}

#Preview("Receive manually · Septocaine") {
    NavigationStack {
        ManualReceiveView(productID: ProductSummary.demo[0].id, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}
