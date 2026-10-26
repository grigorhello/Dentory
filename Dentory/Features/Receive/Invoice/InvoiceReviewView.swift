import SwiftUI

/// Review invoice once read (f23, f38): the banner saying how many lines the reading found, then a card per line with
/// its state and the choice it waits for. Every choice is a write, so in read-only mode the sheet says why instead
/// (MS-142); its sheets are Which product is this? and New product. A received invoice (MS-131) shows when and by whom
/// it was received over its lines, read-only.
struct InvoiceReviewView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.writeAccess) private var writeAccess
    @Bindable var viewModel: InvoiceReviewViewModel
    let banner: String?
    let receivedNotice: String?
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let receivedNotice {
                Notice(receivedNotice, tone: .success, identifier: "invoice.received")
            } else if let banner {
                Notice(banner, identifier: "invoice.banner")
            }
            ForEach(viewModel.lines) { line in
                InvoiceLineCard(viewModel: viewModel, line: line)
            }
        }
        .onChange(of: writeAccess.canWrite, initial: true) { _, canWrite in
            viewModel.isReadOnly = !canWrite
        }
        .onChange(of: viewModel.refusedChanges) {
            writeAccess.showReadOnly()
        }
        .onChange(of: viewModel.message) { _, message in show(message) }
        .onChange(of: viewModel.generalError) { _, error in show(error) }
        .onDisappear(perform: saveWhatIsWaiting)
        .msSheet(item: $viewModel.sheet) { sheet in
            InvoiceReviewSheet(sheet: sheet, viewModel: viewModel, session: session)
        }
    }

    private func show(_ message: InvoiceReviewViewModel.Message?) {
        guard let message else { return }
        dependencies.toasts.show(message.title, detail: message.detail)
        viewModel.clearMessage()
    }

    /// A refused choice or a failed save, as a toast; what was typed stays (PRD §7 errors).
    private func show(_ error: AppError?) {
        guard let error else { return }
        dependencies.toasts.show(error.userMessage)
        viewModel.clearGeneralError()
    }

    /// A lot typed just before leaving is saved on the way out.
    private func saveWhatIsWaiting() {
        Task { await viewModel.flushPendingSaves() }
    }
}
