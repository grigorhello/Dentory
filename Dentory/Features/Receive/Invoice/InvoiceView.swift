import SwiftUI

/// Review invoice (f23, f38), Admin only, pushed by Receive delivery for pages just captured or an invoice to continue
/// reviewing: the reading state, then the read header with the banner and the lines to review over Confirm & receive
/// (MS-130), or what went wrong with a way on. The header's "…" menu discards the invoice. Receive manually, Try again
/// for an upload, the lines' choices and Discard invoice are writes, so in read-only mode the sheet says why instead
/// (MS-142).
struct InvoiceView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: InvoiceViewModel
    let session: Session

    init(document: InvoiceDocument, session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeInvoiceViewModel(document: document, session: session))
    }

    init(invoiceID: UUID, session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeInvoiceViewModel(invoiceID: invoiceID, session: session))
    }

    var body: some View {
        content
            .pushedScreen(
                title: InvoiceViewModel.title, subtitle: viewModel.header, identifier: "invoice",
                subtitleIdentifier: "invoice.header", menu: menu
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.state == .ready, let review = viewModel.review {
                    InvoiceConfirmBar(viewModel: review)
                }
            }
            .task(id: viewModel.attempt) { await viewModel.load() }
            .reloadOnReturn(loadsOnAppear: false) { await viewModel.refresh() }
            .msSheet(isPresented: $viewModel.isConfirmingDiscard) {
                DiscardInvoiceSheet(viewModel: viewModel)
            }
            .onChange(of: viewModel.discarded) { _, discarded in leave(after: discarded) }
            .onChange(of: viewModel.generalError) { _, error in show(error) }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            ListCard {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("invoice.loading")
        case .uploading, .reading:
            InvoiceReadingView(onReceiveManually: receiveManuallyInstead)
        case .uploadFailed:
            InvoiceProblemView(
                text: InvoiceViewModel.uploadFailure, identifier: "invoice.upload", onTryAgain: uploadAgain,
                onReceiveManually: receiveManuallyInstead
            )
        case .loadFailed:
            InvoiceProblemView(
                text: InvoiceViewModel.loadFailure, identifier: "invoice.load", onTryAgain: viewModel.retry
            )
        case .failed:
            InvoiceProblemView(
                text: InvoiceViewModel.readingFailure, identifier: "invoice.failed", onTryAgain: captureAgain,
                onReceiveManually: receiveManually
            )
        case .ready:
            if let review = viewModel.review {
                InvoiceReviewView(viewModel: review, banner: viewModel.banner, session: session)
            }
        case .closed:
            EmptyStateView(InvoiceViewModel.closed)
        }
    }

    /// The "…" menu with Discard invoice, once there is an invoice to discard.
    private var menu: IconMenu? {
        guard viewModel.canDiscard else { return nil }
        return IconMenu(.ellipsis, label: InvoiceViewModel.menuLabel, identifier: "invoice.menu", items: [
            IconMenu.Item(
                title: InvoiceViewModel.discardTitle, identifier: "invoice.menu.discard", isDestructive: true,
                perform: askToDiscard
            )
        ])
    }

    /// The reading state's link: the invoice is set aside, then Receive manually opens (PRD §6.5).
    private func receiveManuallyInstead() {
        writeAccess.perform {
            viewModel.setAside()
            router.push(ReceiveRoute.manual())
        }
    }

    /// After a failed reading the invoice is failed already; the delivery is received by hand.
    private func receiveManually() {
        writeAccess.perform { router.push(ReceiveRoute.manual()) }
    }

    /// The same pages again, under the same invoice.
    private func uploadAgain() {
        writeAccess.perform(viewModel.retry)
    }

    /// A clearer photo or another file: back to Receive delivery's options.
    private func captureAgain() {
        router.pop()
    }

    /// Discard invoice in the menu is a write: in read-only mode the sheet says why instead (MS-142).
    private func askToDiscard() {
        writeAccess.perform(viewModel.askToDiscard)
    }

    /// A discard that failed, as a toast; the question stays for another try.
    private func show(_ error: AppError?) {
        guard let error else { return }
        dependencies.toasts.show(error.userMessage)
        viewModel.clearGeneralError()
    }

    /// Discarded: back to Receive delivery, which no longer lists it, with the toast.
    private func leave(after discarded: InvoiceViewModel.Message?) {
        guard let discarded else { return }
        router.pop()
        dependencies.toasts.show(discarded.title, detail: discarded.detail)
    }
}

#Preview("Review invoice · reading") {
    NavigationStack {
        InvoiceView(invoiceID: DemoInvoiceRepository.readingID, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}

#Preview("Review invoice · read") {
    NavigationStack {
        InvoiceView(invoiceID: DemoInvoiceRepository.readyID, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}
