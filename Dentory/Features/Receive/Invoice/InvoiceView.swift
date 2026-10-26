import SwiftUI

/// Review invoice (f23, f38), Admin only, pushed by Receive delivery for pages just captured or an invoice to continue
/// reviewing. Up to its review (MS-129): the reading state, then the read header with the banner, or what went wrong
/// with a way on. Receive manually and Try again for an upload are writes, so in read-only mode the sheet says why
/// instead (MS-142).
struct InvoiceView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: InvoiceViewModel

    init(document: InvoiceDocument, session: Session, dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeInvoiceViewModel(document: document, session: session))
    }

    init(invoiceID: UUID, session: Session, dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeInvoiceViewModel(invoiceID: invoiceID, session: session))
    }

    var body: some View {
        Group {
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
                InvoiceReadView(banner: viewModel.banner)
            case .closed:
                EmptyStateView(InvoiceViewModel.closed)
            }
        }
        .pushedScreen(
            title: InvoiceViewModel.title, subtitle: viewModel.header, identifier: "invoice",
            subtitleIdentifier: "invoice.header"
        )
        .task(id: viewModel.attempt) { await viewModel.load() }
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
