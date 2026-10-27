import SwiftUI

/// Review invoice (f23, f38), Admin only, pushed by Receive delivery for pages just captured or an invoice to continue
/// reviewing, and by Activity's delivery alert: the reading state, then the read header with the banner and the lines
/// to review over Confirm & receive (MS-130, MS-131), a received delivery's lines read-only under when and by whom it
/// was received, or what went wrong with a way on. The header's "…" menu discards the invoice, or deletes a received
/// invoice's file (MS-146). Receive manually, Try again for an upload, the lines' choices, Confirm & receive and
/// Discard invoice are writes, so in read-only mode the sheet says why instead (MS-142); Delete invoice file stays open
/// there, since an admin deletes the clinic's invoice images at any time (PRD §9, decided on #117).
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
            .invoiceFileDeletion(viewModel, session: session)
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
        case .ready, .received:
            if let review = viewModel.review {
                InvoiceReviewView(
                    viewModel: review, banner: viewModel.banner, receivedNotice: viewModel.receivedNotice,
                    fileNotice: viewModel.fileNotice, session: session
                )
            }
        case .closed:
            EmptyStateView(InvoiceViewModel.closed)
        }
    }

    /// The "…" menu, once it has something to do.
    private var menu: IconMenu? {
        guard let menuItem else { return nil }
        return IconMenu(.ellipsis, label: InvoiceViewModel.menuLabel, identifier: "invoice.menu", items: [menuItem])
    }

    /// Discard invoice once there is an invoice to discard; Delete invoice file on a received invoice that still has
    /// its file (MS-146).
    private var menuItem: IconMenu.Item? {
        if viewModel.canDiscard {
            return IconMenu.Item(
                title: InvoiceViewModel.discardTitle, identifier: "invoice.menu.discard", isDestructive: true,
                perform: askToDiscard
            )
        }
        guard viewModel.canDeleteFile else { return nil }
        return IconMenu.Item(
            title: InvoiceViewModel.deleteFileTitle, identifier: "invoice.menu.deleteFile", isDestructive: true,
            perform: askToDeleteFile
        )
    }

    /// The reading state's link: the invoice is set aside, then Receive manually opens (PRD §6.5).
    private func receiveManuallyInstead() {
        writeAccess.perform {
            viewModel.setAside()
            router.push(ReceiveRoute.manual())
        }
    }

    /// After a failed reading the invoice is set aside too, as by Receive manually instead, so Continue reviewing lists
    /// it no more; the delivery is received by hand.
    private func receiveManually() {
        receiveManuallyInstead()
    }

    /// The same pages again, under the same invoice.
    private func uploadAgain() {
        writeAccess.perform(viewModel.retry)
    }

    /// A clearer photo or another file: the invoice that could not be read is set aside, then Receive delivery's
    /// options are back, without it in their list. Only if this screen is still the one shown once the server has
    /// answered: not after Back, or Receive manually, meanwhile.
    private func captureAgain() {
        let tab = router.selectedTab
        let path = router.path(for: tab)
        Task {
            await viewModel.setAsideToCaptureAgain()
            guard router.path(for: tab) == path else { return }
            router.pop(on: tab)
        }
    }

    /// Discard invoice in the menu is a write: in read-only mode the sheet says why instead (MS-142).
    private func askToDiscard() {
        writeAccess.perform(viewModel.askToDiscard)
    }

    /// Delete invoice file is not: the question opens in read-only mode too, since the invoice images are the clinic's
    /// to delete at any time (PRD §9, decided on #117), and the server lets the admin delete them (MS-146).
    private func askToDeleteFile() {
        viewModel.askToDeleteFile()
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
