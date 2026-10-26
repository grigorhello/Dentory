import Foundation
import Testing
@testable import Dentory

/// Confirm & receive (MS-131): the delivery received once every line is resolved, after the lots and expiries still
/// waiting are saved; the toast counting the products and its Undo; `invoice.confirm` with counts and seconds only; a
/// confirmation queued offline without Undo; a refusal read again from the server; one confirmation at a time; and a
/// received invoice, read-only.
@MainActor
struct InvoiceReceiptViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let invoiceID = UUID()
    private let tempBondID = UUID()

    /// f23's lines, each resolved: Septocaine matched when it was read, the endo kit matched by the admin, Tempbond NE
    /// created on its line and the surcharge ignored.
    private var resolved: [InvoiceLine] {
        [
            InvoiceLine.septo,
            InvoiceLine.endoKit.with(.matched, product: ReceivableProduct.endoKit.id, name: "Endo file kit #15-40"),
            InvoiceLine.tempBond.with(.created, product: tempBondID, name: "Tempbond NE"),
            InvoiceLine.surcharge.with(.skipped, product: nil, name: nil)
        ]
    }

    /// The invoice, uploaded 5 minutes before the demo's now.
    private func invoice(_ lines: [InvoiceLine], status: InvoiceSummary.Status) -> InvoiceSummary {
        InvoiceSummary(
            id: invoiceID, status: status, supplier: "Patterson Dental", number: "INV-10092", total: 449,
            currency: nil, readingStarted: true, lineCount: lines.count, lines: lines,
            createdAt: Session.demoNow.addingTimeInterval(-300)
        )
    }

    private func make(
        _ repository: FakeInvoiceRepository, lines: [InvoiceLine]? = nil, status: InvoiceSummary.Status = .ready,
        analytics: Analytics = NoopAnalytics(), reloads: Counter = Counter()
    ) -> InvoiceReviewViewModel {
        let lines = lines ?? resolved
        repository.lines = lines
        return InvoiceReviewViewModel(
            invoice: invoice(lines, status: status), repository: repository, formatters: formatters,
            analytics: analytics, saveDelay: .seconds(60), reload: { reloads.count += 1 }
        )
    }

    @Test func confirmReceivesTheDeliveryAndCountsItsProducts() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        #expect(viewModel.canConfirm)

        await viewModel.confirm()
        #expect(repository.calls == [.confirm(invoiceID)])
        #expect(viewModel.receipt.received == .init(
            title: "Delivery received", detail: "Inventory increased for 3 products.",
            actionID: FakeInvoiceRepository.actionID
        ))
        #expect(viewModel.receipt.generalError == nil)
    }

    @Test func theLotsAndExpiriesWaitingAreSavedBeforeTheDeliveryIsReceived() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        viewModel[lotOf: InvoiceLine.septo.id] = "B441"
        viewModel[expiryOf: InvoiceLine.septo.id] = YearMonth(year: 2028, month: 3)

        await viewModel.confirm()
        #expect(repository.calls == [
            .batch(InvoiceLine.septo.id, lot: "B441", expiry: CalendarDay(year: 2028, month: 3, day: 1)),
            .confirm(invoiceID)
        ], "The delivery comes in with the lot and expiry as typed")
    }

    @Test func aLotThatCannotBeSavedStopsTheConfirmationWithItsToast() async {
        let repository = FakeInvoiceRepository()
        repository.lineErrors = [AppError.network]
        let viewModel = make(repository)
        viewModel[lotOf: InvoiceLine.septo.id] = "B441"

        await viewModel.confirm()
        #expect(!repository.calls.contains(.confirm(invoiceID)))
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.")
        #expect(viewModel.receipt.received == nil)
        #expect(viewModel.canConfirm, "Confirm & receive is there for another try")
    }

    @Test func aConfirmationQueuedOfflineSaysSoWithoutUndo() async {
        let repository = FakeInvoiceRepository()
        repository.confirmOutcome = .success(.queued)
        let viewModel = make(repository)
        await viewModel.confirm()
        #expect(viewModel.receipt.received?.detail == "Inventory increased for 3 products.")
        #expect(viewModel.receipt.received?.actionID == nil, "No action to undo until the server has it (MS-100 D10)")
    }

    @Test func aRefusalShowsTheServersSentenceAndReadsTheInvoiceAgain() async {
        let repository = FakeInvoiceRepository()
        let refusal = AppError.validation(field: nil, message: "This delivery was already received")
        repository.confirmOutcome = .failure(refusal)
        let reloads = Counter()
        let viewModel = make(repository, reloads: reloads)
        await viewModel.confirm()
        #expect(viewModel.receipt.generalError == refusal)
        #expect(viewModel.receipt.received == nil)
        #expect(reloads.count == 1, "The invoice as the server has it now: received on another device")
        viewModel.receipt.clearGeneralError()
        #expect(viewModel.receipt.generalError == nil)
    }

    @Test func invoiceConfirmCarriesCountsAndSecondsOnly() async {
        let analytics = SpyAnalytics()
        let viewModel = make(FakeInvoiceRepository(), analytics: analytics)
        await viewModel.confirm()
        #expect(analytics.events == [
            .invoiceConfirmed(lines: 4, matched: 1, created: 1, seconds: 300)
        ], "4 lines, 1 matched when read, 1 product created, 5 minutes after the upload (MS-147)")
    }

    @Test func aSecondTapWhileTheDeliveryIsReceivedIsIgnored() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        repository.duringConfirm = {
            await MainActor.run {
                #expect(viewModel.isConfirming)
                #expect(!viewModel.canConfirm, "The button waits")
            }
            await viewModel.confirm()
        }
        await viewModel.confirm()
        #expect(repository.calls == [.confirm(invoiceID)])
        #expect(!viewModel.isConfirming)
    }

    @Test func nothingOnTheLinesChangesWhileTheDeliveryIsReceived() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        let skipped = viewModel.lines[3]
        repository.duringConfirm = {
            await viewModel.reopen(skipped)
            await MainActor.run { viewModel[lotOf: InvoiceLine.septo.id] = "B441" }
        }
        await viewModel.confirm()
        #expect(repository.calls == [.confirm(invoiceID)], "No line is reopened or given a lot mid-receipt")
        #expect(viewModel[lotOf: InvoiceLine.septo.id].isEmpty)
    }

    @Test func undoHandsTheActionBackAndSaysWhatWentWrong() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        #expect(await viewModel.receipt.undo(FakeInvoiceRepository.actionID) == nil)
        #expect(repository.calls == [.undoConfirm(FakeInvoiceRepository.actionID)])

        let late = AppError.validation(field: nil, message: "the undo window has passed")
        repository.undoError = late
        #expect(await viewModel.receipt.undo(FakeInvoiceRepository.actionID) == late)
    }

    @Test func theToastCountsEachProductOnceAndSaysWhenNothingCameIn() {
        let twice = InvoiceLine.line(
            5, "SEPTO 4% 1:100K 50/BX", qty: 1, unit: "boxes", price: 50, .matched,
            product: ReceivableProduct.septocaine
        )
        #expect(InvoiceReceiptViewModel.products(in: resolved + [twice]) == 3, "Septocaine on two lines counts once")
        #expect(InvoiceReceiptViewModel.receivedDetail(products: 1) == "Inventory increased for 1 product.")
        #expect(InvoiceReceiptViewModel.receivedDetail(products: 0) == "Nothing was added to inventory.")
    }

    /// A line read as Matched and changed to another product still counts as matched when read: the state a line was
    /// read in never changes (MS-147, the decision on #101).
    @Test func aLineChangedFromItsMatchStillCountsAsMatchedWhenRead() async {
        let analytics = SpyAnalytics()
        var lines = resolved
        lines[0] = InvoiceLine.septo.with(.matched, product: ReceivableProduct.composite.id, name: "Composite A2")
        let viewModel = make(FakeInvoiceRepository(), lines: lines, analytics: analytics)
        await viewModel.confirm()
        #expect(analytics.events == [.invoiceConfirmed(lines: 4, matched: 1, created: 1, seconds: 300)])
    }

    @Test func aLineWithoutAQuantityAddsNothing() {
        let backorder = InvoiceLine.line(
            5, "GLOVES BACKORDER", qty: nil, unit: "CS", price: nil, .matched, product: ReceivableProduct.gauze
        )
        let viewModel = make(FakeInvoiceRepository(), lines: resolved + [backorder])
        #expect(!backorder.receivesStock && backorder.increasesInventory)
        #expect(viewModel.summary == "3 of 5 lines will increase inventory.")
        #expect(InvoiceReceiptViewModel.products(in: viewModel.lines) == 3)
    }

    @Test func aReceivedInvoiceIsReadOnly() async {
        let repository = FakeInvoiceRepository()
        var lines = resolved
        lines[0].lot = "B441"
        lines[0].expiryMonth = CalendarDay(year: 2028, month: 3, day: 1)
        let viewModel = make(repository, lines: lines, status: .confirmed)
        #expect(viewModel.isReceived)
        #expect(!viewModel.canConfirm, "Nothing left to confirm")
        #expect(!viewModel.canReopen(lines[1]) && lines[1].canReopen, "No badge reopens a line")
        #expect(viewModel.badgeAction(for: lines[0]) == nil && lines[0].canPickAnother, "nor offers another product")

        await viewModel.reopen(lines[1])
        await viewModel.tapBadge(on: lines[0])
        #expect(viewModel.sheet == nil)
        await viewModel.perform(.ignore, on: lines[3])
        await viewModel.confirm()
        viewModel[lotOf: lines[1].id] = "E7"
        #expect(repository.calls.isEmpty)
        #expect(viewModel.refusedChanges == 0, "Not a read-only refusal: there is nothing to change")
        #expect(viewModel.receivedBatch(for: viewModel.lines[0]) == "Expiry Mar 2028\u{00A0}· Lot B441")
        #expect(viewModel.receivedBatch(for: viewModel.lines[2]) == "No expiry")
    }
}
