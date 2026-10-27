import Foundation
import Testing
@testable import Dentory

/// "Delete the invoice file?" (MS-146): Delete file answers the received invoice without its file; a page the server
/// still finds, a lost connection and a refusal show above the buttons with the question kept for Try again, which
/// clears them; one deletion runs at a time; the words are the ticket's.
@MainActor
struct DeleteInvoiceFileViewModelTests {
    private let invoiceID = UUID()
    private let clinicID = Session.demo.clinicID

    private func question(_ repository: FakeInvoiceRepository) -> DeleteInvoiceFileViewModel {
        DeleteInvoiceFileViewModel(invoiceID: invoiceID, clinicID: clinicID, repository: repository)
    }

    /// The received invoice as the server answers it, with or without a page of its file.
    private func received(hasFile: Bool) -> InvoiceSummary {
        InvoiceSummary(
            id: invoiceID, status: .confirmed, supplier: "Patterson Dental", number: "INV-10092", total: 449,
            currency: nil, readingStarted: true, lineCount: 4, lines: InvoiceLine.frames,
            confirmedAt: Session.demoNow, confirmedByName: "Sarah Mitchell", hasFile: hasFile,
            fileDeletedAt: Session.demoNow, fileDeletedByName: "Sarah Mitchell"
        )
    }

    @Test func deleteFileAnswersTheInvoiceWithoutItsFile() async {
        let repository = FakeInvoiceRepository()
        repository.fileDeletion = .success(received(hasFile: false))
        let viewModel = question(repository)

        await viewModel.delete()
        #expect(repository.calls == [.deleteFile(invoiceID, clinic: clinicID)])
        #expect(viewModel.deleted == received(hasFile: false))
        #expect(viewModel.generalError == nil)
        #expect(!viewModel.isDeleting)
    }

    @Test func aPageTheServerStillFindsIsAFailureToTryAgain() async {
        let repository = FakeInvoiceRepository()
        repository.fileDeletion = .success(received(hasFile: true))
        let viewModel = question(repository)

        await viewModel.delete()
        #expect(viewModel.deleted == nil, "The file is not gone while a page is left")
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.")
    }

    @Test func aLostConnectionIsNotQueuedForLater() async {
        let repository = FakeInvoiceRepository()
        repository.fileDeletion = .failure(AppError.network)
        let viewModel = question(repository)

        await viewModel.delete()
        #expect(viewModel.deleted == nil)
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.", "Not \"will be retried\"")
    }

    @Test func aRefusalSaysWhy() async {
        let repository = FakeInvoiceRepository()
        repository.fileDeletion = .failure(AppError.refusal("Only a received invoice's file can be deleted"))
        let viewModel = question(repository)

        await viewModel.delete()
        #expect(viewModel.generalError?.userMessage == "Only a received invoice's file can be deleted.",
            "The server's sentence, in house copy")

        // Only an admin deletes the file, read-only or not (#117): a role changed to Staff meanwhile is refused.
        repository.fileDeletion = .failure(AppError.forbidden)
        await viewModel.delete()
        #expect(viewModel.generalError?.userMessage == "You don't have permission to do this.")
        #expect(viewModel.deleted == nil)
    }

    @Test func tryAgainClearsTheLastFailure() async {
        let repository = FakeInvoiceRepository()
        repository.fileDeletion = .failure(AppError.network)
        let viewModel = question(repository)
        await viewModel.delete()
        #expect(viewModel.generalError != nil)

        repository.fileDeletion = .success(received(hasFile: false))
        await viewModel.delete()
        #expect(viewModel.generalError == nil)
        #expect(viewModel.deleted?.hasFile == false)
        #expect(repository.calls.count == 2)
    }

    @Test func aSecondTapWhileDeletingIsIgnored() async {
        let repository = FakeInvoiceRepository()
        repository.fileDeletion = .success(received(hasFile: false))
        let viewModel = question(repository)
        repository.duringFileDeletion = {
            await MainActor.run { #expect(viewModel.isDeleting, "Delete file waits, and Keep with it") }
            await viewModel.delete()
        }

        await viewModel.delete()
        #expect(repository.calls.count == 1, "One deletion at a time")
        #expect(!viewModel.isDeleting)
    }

    @Test func theWordsAreTheTickets() {
        #expect(InvoiceViewModel.deleteFileTitle == "Delete invoice file")
        #expect(DeleteInvoiceFileViewModel.title == "Delete the invoice file?")
        #expect(DeleteInvoiceFileViewModel.message
            == "Received stock and history stay. Only the image or PDF is removed.")
        #expect(DeleteInvoiceFileViewModel.deleteTitle == "Delete file")
        #expect(DeleteInvoiceFileViewModel.keepTitle == "Keep")
    }
}
