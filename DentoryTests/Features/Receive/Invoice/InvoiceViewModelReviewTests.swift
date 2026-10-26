import Foundation
import Testing
@testable import Dentory

/// Review invoice once read (MS-130): the lines handed to their review in the invoice's currency and read again on
/// return, an invoice received or set aside meanwhile closing, and Discard invoice: asked first, then the pages deleted
/// and the invoice set aside, or the failure shown with the question kept.
@MainActor
struct InvoiceViewModelReviewTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let invoiceID = UUID()

    private func opened(_ repository: FakeInvoiceRepository) -> InvoiceViewModel {
        InvoiceViewModel(
            invoiceID: invoiceID, repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            pause: { _ in }
        )
    }

    @Test func aReadInvoiceShowsItsLinesForReviewInItsOwnCurrency() async throws {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID, currency: "CAD", with: InvoiceLine.frames))]
        let viewModel = opened(repository)
        #expect(viewModel.review == nil)
        await viewModel.load()
        let review = try #require(viewModel.review)
        #expect(review.lines == InvoiceLine.frames)
        #expect(review.invoiceID == invoiceID)
        #expect(review.amount(for: InvoiceLine.septo) == "5 boxes · CA$49.80", "The prices in the invoice's currency")
    }

    @Test func comingBackToTheForegroundReadsTheLinesAgain() async throws {
        let repository = FakeInvoiceRepository()
        let matched = InvoiceLine.endoKit.with(.matched, product: ReceivableProduct.endoKit.id, name: "Endo file kit")
        repository.readings = [
            .success(.ready(invoiceID, with: InvoiceLine.frames)),
            .success(.ready(invoiceID, with: [InvoiceLine.septo, matched, InvoiceLine.tempBond, InvoiceLine.surcharge]))
        ]
        let viewModel = opened(repository)
        await viewModel.load()
        let review = try #require(viewModel.review)

        await viewModel.refresh()
        #expect(viewModel.review === review, "The same lines, refreshed")
        #expect(review.lines[1].state == .matched)
    }

    @Test func anInvoiceReceivedOrSetAsideMeanwhileClosesOnTheNextRead() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [
            .success(.ready(invoiceID, with: InvoiceLine.frames)), .success(.ended(invoiceID, .confirmed))
        ]
        let viewModel = opened(repository)
        await viewModel.load()
        await viewModel.refresh()
        #expect(viewModel.state == .closed)
    }

    @Test func refreshAsksNothingBeforeTheInvoiceIsRead() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.reading(invoiceID))]
        let viewModel = opened(repository)
        await viewModel.refresh()
        #expect(repository.calls.isEmpty, "Loading and reading follow the invoice already")
    }

    @Test func discardInvoiceAsksFirstThenDeletesTheInvoiceAndLeaves() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID, with: InvoiceLine.frames))]
        let viewModel = opened(repository)
        #expect(!viewModel.canDiscard, "Nothing to discard before the invoice opens")
        await viewModel.load()
        #expect(viewModel.canDiscard)

        viewModel.askToDiscard()
        #expect(viewModel.isConfirmingDiscard)
        #expect(!repository.calls.contains(.discard(invoiceID)), "The question comes before anything is deleted")

        await viewModel.discard()
        #expect(repository.calls.last == .discard(invoiceID))
        #expect(!viewModel.isConfirmingDiscard)
        #expect(viewModel.state == .closed)
        #expect(viewModel.discarded == .init(
            title: "Invoice discarded", detail: "Patterson Dental · INV-10092 · $449.00"
        ))
    }

    @Test func keepClosesTheQuestionAndAFailedDiscardKeepsTheInvoice() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID, with: InvoiceLine.frames))]
        repository.discardError = AppError.network
        let viewModel = opened(repository)
        await viewModel.load()
        viewModel.askToDiscard()
        viewModel.keepInvoice()
        #expect(!viewModel.isConfirmingDiscard)

        viewModel.askToDiscard()
        await viewModel.discard()
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.")
        #expect(viewModel.isConfirmingDiscard, "The question stays for Try again")
        #expect(viewModel.state == .ready)
        #expect(viewModel.discarded == nil)
    }

    @Test func aFailedReadingCanBeDiscardedToo() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ended(invoiceID, .failed))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.canDiscard)
        await viewModel.discard()
        #expect(repository.calls.last == .discard(invoiceID))
        #expect(viewModel.discarded?.detail == nil, "A failed reading has no header")
    }

    @Test func theDiscardCopyFollowsTheTicket() {
        #expect(InvoiceViewModel.discardTitle == "Discard invoice")
        #expect(InvoiceViewModel.discardQuestion == "Discard this invoice?")
        #expect(InvoiceViewModel.discardMessage
            == "Nothing is added to inventory, and the invoice's photo or file is deleted.")
        #expect(InvoiceViewModel.keepTitle == "Keep")
    }
}
