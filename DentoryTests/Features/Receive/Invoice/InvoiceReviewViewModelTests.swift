import Foundation
import Testing
@testable import Dentory

/// Review invoice's lines (MS-130): what each state says and offers, every choice saved as it is made and answered by
/// the server, a resolved line reopened in the state it was read in, the lot and expiry saved a moment after the last
/// change and kept as typed, refusals and lost connections, read-only mode, and Confirm & receive waiting for every
/// line (receiving itself is in `InvoiceReceiptViewModelTests`).
@MainActor
struct InvoiceReviewViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let invoiceID = UUID()

    /// The frames' invoice under review, with a recorder of the reloads a refusal asks for.
    private func make(
        _ repository: FakeInvoiceRepository, lines: [InvoiceLine] = InvoiceLine.frames,
        saveDelay: Duration = .milliseconds(10), reloads: Counter = Counter()
    ) -> InvoiceReviewViewModel {
        repository.lines = lines
        return InvoiceReviewViewModel(
            invoice: .ready(invoiceID, with: lines), repository: repository, formatters: formatters,
            analytics: NoopAnalytics(), saveDelay: saveDelay, reload: { reloads.count += 1 }
        )
    }

    private func line(_ number: Int, in viewModel: InvoiceReviewViewModel) throws -> InvoiceLine {
        try #require(viewModel.lines.first { $0.number == number })
    }

    /// Waits, briefly, for work the screen leaves running.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - What the lines say

    @Test func theFramesLinesReadAsF23DrawsThem() {
        let viewModel = make(FakeInvoiceRepository())
        #expect(viewModel.lines.map(viewModel.headline(for:)) == [
            "Septocaine 4% 1:100,000", "Is this Endo file kit #15-40?", "Not in your inventory",
            "Looks like a fee, not a product"
        ])
        #expect(viewModel.lines.map(viewModel.question(for:)) == [
            nil, "Name differs slightly from your product.", "No product with this name exists yet.",
            "Fees and surcharges should not go into stock."
        ])
        #expect(viewModel.lines.map(viewModel.amount(for:)) == [
            "5 boxes · $49.80", "4 boxes · $45.00", "1 pack · $26.40", "1 · $4.80"
        ])
        #expect(viewModel.summary == "Resolve every line to continue.")
        #expect(!viewModel.canConfirm, "Disabled until every line is resolved")
    }

    @Test func eachStateOffersItsTwoChoices() throws {
        let viewModel = make(FakeInvoiceRepository())
        let choices = viewModel.lines.map { viewModel.choices(for: $0).map { [$0.first, $0.second] } }
        #expect(choices == [nil, [.yesMatch, .createNew], [.addNew, .pickExisting], [.ignore, .pickProduct]])
        let all: [InvoiceReviewViewModel.Choice] = [
            .yesMatch, .createNew, .addNew, .pickExisting, .ignore, .pickProduct
        ]
        #expect(all.map(InvoiceReviewViewModel.title(of:))
            == ["Yes, match", "No, create new", "Add new", "Pick existing", "Ignore", "Pick product"])
        #expect(InvoiceReviewViewModel.isPrimary(.yesMatch) && InvoiceReviewViewModel.isPrimary(.addNew))
        #expect(!InvoiceReviewViewModel.isPrimary(.ignore), "Ignore is tertiary, as f23 draws it")
    }

    @Test func amountsReadInTheUnitAsReadAndThePriceOfOne() {
        let viewModel = make(FakeInvoiceRepository())
        let twoBoxes = InvoiceLine.line(9, "GLOVES", qty: 2, unit: "box", price: 12, .newProduct)
        let oneBox = InvoiceLine.line(9, "GLOVES", qty: 1, unit: "boxes", price: nil, .newProduct)
        let price = Decimal(string: "0.9960")
        let noQuantity = InvoiceLine.line(9, "GLOVES", qty: nil, unit: "box", price: price, .newProduct)
        #expect(viewModel.amount(for: twoBoxes) == "2 boxes · $12.00")
        #expect(viewModel.amount(for: oneBox) == "1 box")
        #expect(viewModel.amount(for: noQuantity) == "$0.996", "A unit price keeps up to four decimals")
    }

    // MARK: - Choices

    @Test func yesMatchMatchesTheSuggestedProductAndItsBadgeReopensTheLine() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        await viewModel.perform(.yesMatch, on: InvoiceLine.endoKit)
        let matched = try line(2, in: viewModel)
        #expect(repository.calls == [.match(InvoiceLine.endoKit.id, product: ReceivableProduct.endoKit.id)])
        #expect(matched.state == .matched)
        #expect(matched.readState == .possibleMatch, "The state it was read in stays (MS-147)")
        #expect(matched.canReopen)

        await viewModel.reopen(matched)
        #expect(try line(2, in: viewModel).state == .possibleMatch)
        #expect(repository.calls.last == .reopen(InvoiceLine.endoKit.id))
    }

    @Test func aLineMatchedWhenReadHasNothingToReopen() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        #expect(!InvoiceLine.septo.canReopen)
        await viewModel.reopen(InvoiceLine.septo)
        #expect(repository.calls.isEmpty)
    }

    @Test func addNewAndNoCreateNewOpenNewProductForTheLine() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        await viewModel.perform(.addNew, on: InvoiceLine.tempBond)
        #expect(viewModel.sheet == .newProduct(InvoiceLine.tempBond))
        await viewModel.perform(.createNew, on: InvoiceLine.endoKit)
        #expect(viewModel.sheet == .newProduct(InvoiceLine.endoKit))
        #expect(repository.calls.isEmpty, "Nothing is saved before the product is created")
    }

    @Test func aProductCreatedForTheLineMakesItCreated() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        await viewModel.perform(.addNew, on: InvoiceLine.tempBond)
        #expect(viewModel.sheet == .newProduct(InvoiceLine.tempBond))
        let productID = UUID()

        await viewModel.productCreated(productID, for: InvoiceLine.tempBond)
        #expect(viewModel.sheet == nil)
        #expect(repository.calls == [.createLine(InvoiceLine.tempBond.id, product: productID)])
        let created = try line(3, in: viewModel)
        #expect(created.state == .created)
        #expect(viewModel.headline(for: created) == "Tempbond NE · new product")
        #expect(viewModel.message == .init(title: "Product created", detail: "Tempbond NE · add expiry on the line"))
    }

    @Test func aCreatedProductsLineIsTriedAgainWhenTheConnectionDrops() async throws {
        let repository = FakeInvoiceRepository()
        repository.lineErrors = [AppError.network]
        let viewModel = make(repository)
        let productID = UUID()
        await viewModel.productCreated(productID, for: InvoiceLine.tempBond)
        #expect(repository.calls == [
            .createLine(InvoiceLine.tempBond.id, product: productID),
            .createLine(InvoiceLine.tempBond.id, product: productID)
        ])
        #expect(try line(3, in: viewModel).state == .created)
        #expect(viewModel.generalError == nil)
    }

    @Test func pickExistingAndPickProductOpenWhichProductIsThisAndATapMatches() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        await viewModel.perform(.pickExisting, on: InvoiceLine.tempBond)
        #expect(viewModel.sheet == .match(InvoiceLine.tempBond))
        await viewModel.perform(.pickProduct, on: InvoiceLine.surcharge)
        #expect(viewModel.sheet == .match(InvoiceLine.surcharge))

        await viewModel.choose(ReceivableProduct.gauze.id, for: InvoiceLine.surcharge)
        #expect(viewModel.sheet == nil)
        #expect(repository.calls == [.match(InvoiceLine.surcharge.id, product: ReceivableProduct.gauze.id)])
        #expect(try line(4, in: viewModel).state == .matched)
    }

    @Test func ignoreSkipsAFeeAndUndoReopensIt() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        await viewModel.perform(.ignore, on: InvoiceLine.surcharge)
        let skipped = try line(4, in: viewModel)
        #expect(skipped.state == .skipped)
        #expect(viewModel.headline(for: skipped) == "Ignored · not added to inventory")
        #expect(viewModel.choices(for: skipped) == nil)

        await viewModel.reopen(skipped)
        #expect(try line(4, in: viewModel).state == .needsReview)
        #expect(repository.calls == [.skip(InvoiceLine.surcharge.id), .reopen(InvoiceLine.surcharge.id)])
    }

    @Test func everyLineResolvedEnablesConfirmAndCountsWhatGoesIntoStock() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        await viewModel.perform(.yesMatch, on: InvoiceLine.endoKit)
        await viewModel.productCreated(UUID(), for: InvoiceLine.tempBond)
        #expect(viewModel.summary == "Resolve every line to continue.")
        await viewModel.perform(.ignore, on: InvoiceLine.surcharge)

        #expect(viewModel.allResolved)
        #expect(viewModel.canConfirm)
        #expect(viewModel.summary == "3 of 4 lines will increase inventory.")
        await viewModel.confirm()
        #expect(repository.calls.last == .confirm(invoiceID), "Confirm & receive receives the delivery (MS-131)")
    }

    @Test func oneLineReadsInTheSingular() {
        let viewModel = make(FakeInvoiceRepository(), lines: [InvoiceLine.septo])
        #expect(viewModel.summary == "1 of 1 line will increase inventory.")
    }

    @Test func aRefusalShowsTheServersSentenceAndReadsTheInvoiceAgain() async throws {
        let repository = FakeInvoiceRepository()
        let refusal = AppError.validation(field: nil, message: "This invoice is no longer waiting for review.")
        repository.lineErrors = [refusal]
        let reloads = Counter()
        let viewModel = make(repository, reloads: reloads)
        await viewModel.perform(.yesMatch, on: InvoiceLine.endoKit)
        #expect(viewModel.generalError == refusal)
        #expect(reloads.count == 1)
        #expect(try line(2, in: viewModel).state == .possibleMatch)
    }

    @Test func aLostConnectionLeavesTheLineForTheAdminToTryAgain() async throws {
        let repository = FakeInvoiceRepository()
        repository.lineErrors = [AppError.network]
        let reloads = Counter()
        let viewModel = make(repository, reloads: reloads)
        await viewModel.perform(.ignore, on: InvoiceLine.surcharge)
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.", "Nothing here is retried later")
        #expect(reloads.count == 0)
        #expect(try line(4, in: viewModel).state == .needsReview)
        #expect(!viewModel.isSaving(InvoiceLine.surcharge))
    }

    @Test func aSecondTapWhileTheLineIsSavedIsIgnored() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        repository.duringLine = {
            await MainActor.run { #expect(viewModel.isSaving(InvoiceLine.surcharge)) }
            await viewModel.perform(.ignore, on: InvoiceLine.surcharge)
        }
        await viewModel.perform(.ignore, on: InvoiceLine.surcharge)
        #expect(repository.calls == [.skip(InvoiceLine.surcharge.id)])
        #expect(viewModel.savingLineIDs.isEmpty)
    }

    // MARK: - Lot and expiry

    @Test func theLotAndExpiryAreSavedTogetherAMomentAfterTheLastChange() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        let id = InvoiceLine.septo.id
        viewModel[lotOf: id] = "B4"
        viewModel[lotOf: id] = "B44"
        viewModel[lotOf: id] = " B441 "
        viewModel[expiryOf: id] = YearMonth(year: 2028, month: 3)
        #expect(repository.calls.isEmpty, "Nothing is sent while the admin types")
        await eventually { !repository.calls.isEmpty }
        try await Task.sleep(for: .milliseconds(30))
        let march = CalendarDay(year: 2028, month: 3, day: 1)
        #expect(repository.calls == [.batch(id, lot: "B441", expiry: march)])
        #expect(viewModel[lotOf: id] == " B441 ", "What was typed stays on screen")
        #expect(viewModel[expiryOf: id] == YearMonth(year: 2028, month: 3))
    }

    @Test func anEmptyLotIsNoneAndALotKeepsSixtyCharacters() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository, saveDelay: .seconds(60))
        let id = InvoiceLine.septo.id
        viewModel[lotOf: id] = String(repeating: "L", count: 70)
        #expect(viewModel[lotOf: id].count == 60)
        viewModel[lotOf: id] = "   "
        viewModel.saveBatchNow(of: id)
        await eventually { !repository.calls.isEmpty }
        #expect(repository.calls == [.batch(id, lot: nil, expiry: nil)])
    }

    @Test func returnSavesTheLotAtOnceAndLeavingSavesWhatIsWaiting() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository, saveDelay: .seconds(60))
        viewModel[lotOf: InvoiceLine.septo.id] = "A112"
        viewModel.saveBatchNow(of: InvoiceLine.septo.id)
        await eventually { !repository.calls.isEmpty }
        viewModel[lotOf: InvoiceLine.endoKit.id] = "E7"
        await viewModel.flushPendingSaves()
        #expect(repository.calls == [
            .batch(InvoiceLine.septo.id, lot: "A112", expiry: nil),
            .batch(InvoiceLine.endoKit.id, lot: "E7", expiry: nil)
        ])
        await viewModel.flushPendingSaves()
        #expect(repository.calls.count == 2, "Nothing saved twice")
    }

    @Test func aLotNotSavedYetStaysOverAFreshReading() throws {
        let viewModel = make(FakeInvoiceRepository(), saveDelay: .seconds(60))
        viewModel[lotOf: InvoiceLine.septo.id] = "A112"
        let fresh = InvoiceLine.frames.map { line in
            line.id == InvoiceLine.endoKit.id ? line.with(.matched, product: UUID(), name: "Endo") : line
        }
        viewModel.update(with: fresh)
        #expect(viewModel[lotOf: InvoiceLine.septo.id] == "A112")
        #expect(try line(2, in: viewModel).state == .matched, "The rest follows the server")
    }

    @Test func aLotThatFailedToSaveStaysAsTypedWithTheToast() async {
        let repository = FakeInvoiceRepository()
        repository.lineErrors = [AppError.network]
        let viewModel = make(repository)
        viewModel[lotOf: InvoiceLine.septo.id] = "A112"
        await eventually { viewModel.generalError != nil }
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.")
        #expect(viewModel[lotOf: InvoiceLine.septo.id] == "A112")
        viewModel.clearGeneralError()
        await viewModel.flushPendingSaves()
        #expect(repository.calls.count == 2, "Leaving the screen tries again")
    }

    @Test func readOnlyModeKeepsTheLotAndAsksForTheSheet() {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        viewModel.isReadOnly = true
        viewModel[lotOf: InvoiceLine.septo.id] = "A112"
        viewModel[expiryOf: InvoiceLine.septo.id] = YearMonth(year: 2028, month: 1)
        #expect(viewModel.refusedChanges == 2)
        #expect(viewModel[lotOf: InvoiceLine.septo.id].isEmpty)
        #expect(viewModel[expiryOf: InvoiceLine.septo.id] == nil)
        #expect(repository.calls.isEmpty)
    }

    @Test func discardingDropsWhatWasTyped() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository, saveDelay: .milliseconds(20))
        viewModel[lotOf: InvoiceLine.septo.id] = "A112"
        viewModel.dropPendingSaves()
        try await Task.sleep(for: .milliseconds(60))
        await viewModel.flushPendingSaves()
        #expect(repository.calls.isEmpty)
    }

    @Test func theInputsReadAsTheFrameAndTheMonthsAsAddExpiry() {
        let viewModel = make(FakeInvoiceRepository())
        #expect(InvoiceReviewViewModel.expiryLabel == "Expiry")
        #expect(InvoiceReviewViewModel.expiryPlaceholder == "Month")
        #expect(InvoiceReviewViewModel.lotLabel == "Lot (optional)")
        #expect(InvoiceReviewViewModel.lotPlaceholder == "Free text")
        #expect(InvoiceReviewViewModel.noExpiryHint == "No expiry → listed under Missing expiry.")
        #expect(viewModel.openingMonth == YearMonth(year: 2026, month: 10))
        #expect(viewModel.expiryYears(for: InvoiceLine.septo) == 2023...2036)
        #expect(viewModel.monthTitle(YearMonth(year: 2027, month: 3)) == "Mar 2027")
    }
}

/// How many times something happened, seen from a closure.
@MainActor
final class Counter {
    var count = 0
}
