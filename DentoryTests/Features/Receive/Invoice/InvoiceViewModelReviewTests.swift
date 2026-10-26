import Foundation
import Testing
@testable import Dentory

/// Review invoice once read (MS-130): the lines handed to their review in the invoice's currency and read again on
/// return, an invoice set aside meanwhile closing, one received showing its lines read-only under who received it and
/// when (MS-131), and Discard invoice: asked first, then the invoice set aside and its pages deleted, or the failure
/// shown with the question kept, or, for a delivery received on another device, the received invoice.
@MainActor
struct InvoiceViewModelReviewTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let invoiceID = UUID()

    private func opened(
        _ repository: FakeInvoiceRepository, analytics: Analytics = NoopAnalytics()
    ) -> InvoiceViewModel {
        InvoiceViewModel(
            invoiceID: invoiceID, repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            analytics: analytics, pause: { _ in }
        )
    }

    /// The frames' invoice received by Sarah at the demo's now, its lines resolved.
    private var received: InvoiceSummary {
        let lines = [
            InvoiceLine.septo, InvoiceLine.endoKit.with(.matched, product: ReceivableProduct.endoKit.id, name: "Endo"),
            InvoiceLine.tempBond.with(.created, product: UUID(), name: "Tempbond NE"),
            InvoiceLine.surcharge.with(.skipped, product: nil, name: nil)
        ]
        return InvoiceSummary(
            id: invoiceID, status: .confirmed, supplier: "Patterson Dental", number: "INV-10092", total: 449,
            currency: nil, readingStarted: true, lineCount: 4, lines: lines,
            createdAt: Session.demoNow.addingTimeInterval(-600), confirmedAt: Session.demoNow,
            confirmedByName: "Sarah Mitchell"
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

    @Test func anInvoiceSetAsideMeanwhileClosesOnTheNextRead() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [
            .success(.ready(invoiceID, with: InvoiceLine.frames)), .success(.ended(invoiceID, .discarded))
        ]
        let viewModel = opened(repository)
        await viewModel.load()
        await viewModel.refresh()
        #expect(viewModel.state == .closed)
    }

    @Test func aReceivedInvoiceShowsItsLinesReadOnlyUnderWhoReceivedItAndWhen() async throws {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(received)]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.state == .received)
        #expect(viewModel.header == "Patterson Dental · INV-10092 · $449.00")
        #expect(viewModel.banner == nil)
        #expect(viewModel.receivedNotice == "Received · \(formatters.dateTime(Session.demoNow)) · Sarah")
        #expect(!viewModel.canDiscard, "A received invoice is not discarded")
        let review = try #require(viewModel.review)
        #expect(review.isReceived && !review.canConfirm)
        #expect(review.lines.count == 4)
    }

    @Test func aDeliveryReceivedOnAnotherDeviceTurnsTheReviewReadOnlyOnTheNextRead() async throws {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID, with: InvoiceLine.frames)), .success(received)]
        let viewModel = opened(repository)
        await viewModel.load()
        let review = try #require(viewModel.review)
        #expect(!review.isReceived)

        await viewModel.refresh()
        #expect(viewModel.state == .received)
        #expect(viewModel.review?.isReceived == true)
        #expect(viewModel.review !== review, "The lines are shown again, read-only")
    }

    @Test func theAnalyticsReachTheConfirmation() async throws {
        let analytics = SpyAnalytics()
        let repository = FakeInvoiceRepository()
        let base = received
        let ready = InvoiceSummary(
            id: invoiceID, status: .ready, supplier: base.supplier, number: base.number, total: base.total,
            currency: nil, readingStarted: true, lineCount: 4, lines: base.lines, createdAt: base.createdAt
        )
        repository.readings = [.success(ready)]
        repository.lines = ready.lines
        let viewModel = opened(repository, analytics: analytics)
        await viewModel.load()
        await viewModel.review?.confirm()
        #expect(analytics.events.map(\.name) == [.invoiceConfirm])
        #expect(analytics.events.first?.payload["duration_s"] == .number(600))
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

    @Test func aDiscardRefusedForADeliveryReceivedElsewhereShowsItReceived() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID, with: InvoiceLine.frames)), .success(received)]
        let refusal = AppError.validation(field: nil, message: "This delivery was already received")
        repository.discardError = refusal
        let viewModel = opened(repository)
        await viewModel.load()
        viewModel.askToDiscard()

        await viewModel.discard()
        #expect(viewModel.generalError == refusal, "The server's sentence, as a toast")
        #expect(!viewModel.isConfirmingDiscard, "The question closes")
        #expect(viewModel.state == .received, "and the invoice shows as received, its photo kept")
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
