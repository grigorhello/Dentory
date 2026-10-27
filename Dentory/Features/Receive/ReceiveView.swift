import SwiftUI

/// Receive delivery (f22), Admin only, pushed from Home's Receive delivery row, Inventory's empty clinic and a delivery
/// alert: the three ways to receive, the line saying nothing changes before Confirm, the invoices to continue reviewing
/// and the lines waiting for delivery.
struct ReceiveView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: ReceiveViewModel
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeReceiveViewModel(
            session: session, canScan: DocumentScanner.isAvailable
        ))
    }

    var body: some View {
        content
            .pushedScreen(title: "Receive delivery", identifier: "receive")
            .reloadOnReturn { await viewModel.load() }
            .tabDestination(for: ReceiveRoute.self) { route in
                switch route {
                case .manual(let productID):
                    ManualReceiveView(productID: productID, session: session, dependencies: dependencies)
                case .invoice(let invoiceID):
                    InvoiceView(invoiceID: invoiceID, session: session, dependencies: dependencies)
                case .newInvoice(let document):
                    InvoiceView(document: document, session: session, dependencies: dependencies)
                }
            }
            .receiveCapture(viewModel)
            .onChange(of: viewModel.message) { _, message in show(message) }
            .onChange(of: viewModel.pendingRoute) { _, route in open(route) }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: Spacing.md) {
            ReceiveOptionCard(
                icon: .camera, title: "Take a photo", detail: "Invoice or packing slip.", isFeatured: true,
                action: takePhoto
            )
            .accessibilityIdentifier("receive.photo")
            ReceiveOptionCard(
                icon: .upload, title: "Upload PDF or image", detail: "From files or email.",
                action: uploadFile
            )
            .accessibilityIdentifier("receive.upload")
            ReceiveOptionCard(
                icon: .penLine, title: "Receive manually", detail: "No invoice, or a single item.",
                action: receiveManually
            )
            .accessibilityIdentifier("receive.manual")
        }
        Text(ReceiveViewModel.reassurance)
            .textStyle(.caption12)
            .foregroundStyle(Color.ms.textSecondary)
            .accessibilityIdentifier("receive.reassurance")
        ReceiveLists(viewModel: viewModel, onContinue: viewModel.continueReviewing)
    }

    private func show(_ message: ReceiveViewModel.Message?) {
        guard let message else { return }
        dependencies.toasts.show(message.title, detail: message.detail)
        viewModel.clearMessage()
    }

    /// Captured pages, or an invoice to continue, go on to Review invoice.
    private func open(_ route: ReceiveRoute?) {
        guard let route else { return }
        router.push(route)
        viewModel.clearPendingRoute()
    }

    /// Receiving is a write, and a captured invoice is uploaded at once (MS-129): in read-only mode the sheet says why
    /// instead (MS-142), should the trial end while this screen is open.
    private func takePhoto() {
        writeAccess.perform(viewModel.takePhoto)
    }

    private func uploadFile() {
        #if DEBUG
        // `-receiveFile <path>`: the file is taken as if picked in Files, Apple's own picker, which the end-to-end
        // flows cannot drive (MS-136).
        if let path = UserDefaults.standard.string(forKey: "receiveFile") {
            let url = URL(filePath: path)
            writeAccess.perform {
                Task { await viewModel.capture { () async throws(InvoiceCaptureError) in
                    try await InvoiceCapture.document(fileAt: url)
                } }
            }
            return
        }
        #endif
        writeAccess.perform(viewModel.uploadFile)
    }

    private func receiveManually() {
        writeAccess.perform { router.push(ReceiveRoute.manual()) }
    }
}

#Preview("Receive delivery") {
    NavigationStack {
        ReceiveView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .home))
    .environment(\.session, Session.demo)
}
