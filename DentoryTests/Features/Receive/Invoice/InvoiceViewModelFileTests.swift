import Foundation
import Testing
@testable import Dentory

/// Delete invoice file on Review invoice (MS-146): offered only on a received invoice that still has its file, asked
/// before anything is deleted, and answered with the invoice shown without its file, its lines kept, under when and by
/// whom the file was deleted.
@MainActor
struct InvoiceViewModelFileTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let invoiceID = UUID()
    private let deletedAt = Session.demoNow.addingTimeInterval(3_600)
    /// "Invoice file deleted · Oct 2 · 10:41 AM · Grigor", with the no-break space before each "·" (MS-136 V-16).
    private var deletedByGrigor: String {
        "Invoice file deleted\u{00A0}· \(formatters.dateTime(deletedAt))\u{00A0}· Grigor"
    }

    private func opened(_ repository: FakeInvoiceRepository) -> InvoiceViewModel {
        InvoiceViewModel(
            invoiceID: invoiceID, repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            pause: { _ in }
        )
    }

    /// The frames' invoice received by Sarah, with its photo, or after Grigor deleted it.
    private func received(hasFile: Bool = true, deletedBy name: String? = "Grigor Grigoryan") -> InvoiceSummary {
        InvoiceSummary(
            id: invoiceID, status: .confirmed, supplier: "Patterson Dental", number: "INV-10092", total: 449,
            currency: nil, readingStarted: true, lineCount: 4, lines: InvoiceLine.frames,
            confirmedAt: Session.demoNow, confirmedByName: "Sarah Mitchell", hasFile: hasFile,
            fileDeletedAt: hasFile ? nil : deletedAt, fileDeletedByName: hasFile ? nil : name
        )
    }

    @Test func aReceivedInvoiceWithItsFileOffersToDeleteIt() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(received())]
        let viewModel = opened(repository)
        #expect(!viewModel.canDeleteFile, "Nothing to delete before the invoice opens")
        await viewModel.load()
        #expect(viewModel.canDeleteFile)
        #expect(!viewModel.canDiscard, "A received invoice is not discarded")
        #expect(viewModel.fileNotice == nil)
    }

    @Test func anInvoiceNotReceivedOffersNoFileDeletion() async {
        for answer in [InvoiceSummary.ready(invoiceID, with: InvoiceLine.frames), .ended(invoiceID, .failed)] {
            let repository = FakeInvoiceRepository()
            var withFile = answer
            withFile.hasFile = true
            repository.readings = [.success(withFile)]
            let viewModel = opened(repository)
            await viewModel.load()
            #expect(!viewModel.canDeleteFile, "\(answer.status) is discarded instead, which deletes its file")
            #expect(viewModel.canDiscard)
        }
    }

    @Test func aReceivedInvoiceWithoutItsFileSaysWhenAndByWhom() async throws {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(received(hasFile: false))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(!viewModel.canDeleteFile, "Nothing left to delete")
        #expect(viewModel.fileNotice == deletedByGrigor)
        let receivedAt = formatters.dateTime(Session.demoNow)
        #expect(viewModel.receivedNotice == "Received\u{00A0}· \(receivedAt)\u{00A0}· Sarah")
        let review = try #require(viewModel.review)
        #expect(review.isReceived && review.lines.count == 4, "The lines stay, read-only")
    }

    @Test func aFileDeletedBySomeoneNoLongerKnownStillSaysWhen() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(received(hasFile: false, deletedBy: nil))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.fileNotice == "Invoice file deleted\u{00A0}· \(formatters.dateTime(deletedAt))")
    }

    @Test func aPageLeftAfterADeletionCutShortIsOfferedAgain() async {
        let repository = FakeInvoiceRepository()
        var cutShort = received(hasFile: true)
        cutShort.fileDeletedAt = deletedAt
        cutShort.fileDeletedByName = "Grigor Grigoryan"
        repository.readings = [.success(cutShort)]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.canDeleteFile)
        #expect(viewModel.fileNotice == nil, "Not deleted while a page is left")
    }

    @Test func deleteInvoiceFileAsksFirstAndKeepClosesTheQuestion() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(received())]
        let viewModel = opened(repository)
        await viewModel.load()

        viewModel.askToDeleteFile()
        #expect(viewModel.isConfirmingFileDeletion)
        viewModel.keepFile()
        #expect(!viewModel.isConfirmingFileDeletion)
        #expect(repository.calls == [.invoice(invoiceID)], "The question deletes nothing")
        #expect(viewModel.canDeleteFile)
    }

    @Test func theAnswerShowsTheInvoiceWithoutItsFileAndItsLines() async throws {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(received())]
        let viewModel = opened(repository)
        await viewModel.load()
        let review = try #require(viewModel.review)
        viewModel.askToDeleteFile()

        viewModel.fileDeleted(received(hasFile: false))
        #expect(!viewModel.isConfirmingFileDeletion, "The question closes")
        #expect(viewModel.state == .received)
        #expect(!viewModel.canDeleteFile, "The menu has nothing left to offer")
        #expect(viewModel.fileNotice == deletedByGrigor)
        #expect(viewModel.review === review, "The same lines, still read-only")
        #expect(review.lines.count == 4)
        #expect(viewModel.header == "Patterson Dental\u{00A0}· INV-10092\u{00A0}· $449.00")
    }
}
