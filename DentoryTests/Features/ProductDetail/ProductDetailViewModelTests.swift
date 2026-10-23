import Foundation
import Testing
@testable import Dentory

@MainActor
struct ProductDetailViewModelTests {
    /// October 2, 2026 in New York, the frames' day: the demo batches expire in December.
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeProductDetailRepository = FakeProductDetailRepository(),
        cache: ResponseCaching = InMemoryResponseCache(),
        analytics: SpyAnalytics = SpyAnalytics()
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            userID: Session.demo.userID, productID: ProductSummary.demo[0].id, analytics: analytics
        )
    }

    @Test func loadsTheProductAndReadsItsHeaderAndCard() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.state == .loading)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(repository.detailCalls == [ProductSummary.demo[0].id])
        #expect(viewModel.contextLine == "Anesthetic · 1 box = 50 cartridges")
        #expect(viewModel.availableText == "54")
        #expect(viewModel.minimumText == "20")
        #expect(viewModel.targetText == "60")
        #expect(viewModel.estimateLine == "System estimate · 38 cartridges used in 30 days")
        #expect(viewModel.countedLine == "Counted Oct 1")
        #expect(viewModel.recommendationLine == nil, "Healthy products get no recommendation")
        #expect(!viewModel.isMultiUse)
    }

    @Test func theContextLineWithoutAPackNamesTheUnit() async {
        let detail = ProductDetail.fixture(categoryName: nil, packUnit: nil, packSize: nil)
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.contextLine == "cartridges")
    }

    @Test func aLowProductRecommendsTheDifferenceToTheTarget() async {
        let detail = ProductDetail.fixture(status: .low, quantity: 12, lastCountedAt: nil)
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.recommendationLine == "Recommended: add 48 cartridges")
        #expect(viewModel.countedLine == "Never counted")
        #expect(viewModel.suggestedToBuyQuantity == 48)
    }

    @Test func batchRowsAreSoonestFirstWithTheDaysLeftAndTheTotals() async {
        let viewModel = make()
        await viewModel.load()
        let rows = viewModel.batchRows
        #expect(rows.map(\.lot) == ["A112", "B441"])
        #expect(rows.first?.dateText == "Dec 2026", "Batches have month precision, so no day is shown")
        #expect(rows.first?.daysText == "in 90 days", "Days run to the last day of the expiry month (PRD)")
        #expect(rows.first?.daysTone == .warning)
        #expect(rows.map(\.quantityText) == ["20", "34"])
        #expect(viewModel.expiryTotalLine == "54 of 54 tracked · 54 expire within 90 days")
        #expect(viewModel.unit == "cartridges")
    }

    @Test func undatedStockCountsInTheTotalButHasNoRow() async {
        let undated = ProductBatch(id: UUID(), expiryMonth: nil, lot: nil, quantity: 4)
        let detail = ProductDetail.fixture(quantity: 58, batches: ProductDetail.demoSeptocaine().batches + [undated])
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.batchRows.count == 2)
        #expect(viewModel.expiryTotalLine == "54 of 58 tracked · 54 expire within 90 days")
    }

    @Test func daysLeftTonesFollowThePRD() {
        #expect(ProductDetailViewModel.tone(forDaysLeft: -1) == .danger)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 30) == .danger)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 31) == .warning)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 90) == .warning)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 91) == .neutral)
    }

    @Test func historyRowsReadTheDeltaWhatHappenedAndWho() async {
        let viewModel = make()
        await viewModel.load()
        let rows = viewModel.historyRows
        #expect(rows.map(\.deltaText) == ["43 → 41", "−2", "+40"])
        #expect(rows.map(\.deltaTone) == [.neutral, .danger, .success])
        #expect(rows.map(\.description) == [
            "Physical count · Michael", "Root canal · Sarah", "Invoice INV-10092 · Michael"
        ])
        #expect(rows.map(\.dateText) == ["Oct 1", "Oct 1", "Sep 30"])
    }

    @Test func aRowThatMovedNothingReadsZeroInTheNeutralTone() async {
        let opened = StockTransaction(
            id: UUID(), type: .adjustment, delta: 0, quantityBefore: 3, quantityAfter: 3,
            reason: nil, referenceLabel: "Opened a new bottle", at: Session.demoNow, byName: "Sarah Mitchell"
        )
        let detail = ProductDetail.fixture(
            tracking: .multiUse, quantity: 3, unopened: 1, openCount: 2, history: [opened]
        )
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        let row = viewModel.historyRows.first
        #expect(row?.deltaText == "0", "A bottle opened is no addition (MS-100 D5)")
        #expect(row?.deltaTone == .neutral)
        #expect(row?.description == "Opened a new bottle · Sarah")
    }

    @Test func theExpiryTotalOfAMultiUseProductCountsBatchesNotOpenBottles() async {
        let unopened = ProductBatch(
            id: UUID(), expiryMonth: CalendarDay(year: 2028, month: 6, day: 1), lot: nil, quantity: 1
        )
        let detail = ProductDetail.fixture(
            tracking: .multiUse, quantity: 3, unopened: 1, openCount: 2, batches: [unopened],
            openBottles: [
                OpenBottle(id: UUID(), openedAt: Session.demoNow, openedByName: "Sarah Mitchell"),
                OpenBottle(id: UUID(), openedAt: Session.demoNow, openedByName: "Michael Reyes")
            ]
        )
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(
            viewModel.expiryTotalLine == "1 of 1 tracked · 0 expire within 90 days",
            "Open bottles are not undated stock"
        )
    }

    @Test func aRowWithoutReasonOrReferenceNamesItsKind() {
        let disposal = StockTransaction(
            id: UUID(), type: .disposal, delta: -3, quantityBefore: 10, quantityAfter: 7, reason: nil,
            referenceLabel: nil, at: Session.demoNow, byName: "Sarah Mitchell"
        )
        #expect(ProductDetailViewModel.label(for: disposal) == "Disposed")
        #expect(ProductDetailViewModel.deltaText(for: disposal, formatters: formatters) == "−3")
    }

    @Test func bottlesCardReadsTheCountsAndWhoOpenedWhat() async {
        let opened = Session.demoNow.addingTimeInterval(-3 * 86_400)
        let detail = ProductDetail.fixture(
            tracking: .multiUse, quantity: 3, unopened: 1, openCount: 2,
            openBottles: [
                OpenBottle(id: UUID(), openedAt: opened, openedByName: "Sarah Mitchell"),
                OpenBottle(id: UUID(), openedAt: Session.demoNow, openedByName: "Michael Reyes")
            ]
        )
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.isMultiUse)
        #expect(viewModel.bottlesLine == "1 unopened · 2 open")
        #expect(viewModel.canOpenNewBottle)
        #expect(viewModel.bottleRows.map(\.title) == ["Open · Sarah", "Open · Michael"])
        #expect(viewModel.bottleRows.map(\.subtitle) == ["opened 3 days ago", "opened today"])
    }

    @Test func addToBuyAddsTheSuggestedQuantityAndUndoRemovesIt() async {
        let repository = FakeProductDetailRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(repository: repository, analytics: analytics)
        await viewModel.load()
        #expect(viewModel.addToBuyTitle == "Add to buy")
        #expect(!viewModel.isOnToBuy)
        await viewModel.addToBuy()
        #expect(repository.adds == [.init(
            clinicID: Session.demo.clinicID, productID: ProductSummary.demo[0].id, quantity: 6,
            userID: Session.demo.userID
        )])
        #expect(viewModel.isOnToBuy)
        #expect(viewModel.addToBuyTitle == "On To buy")
        #expect(viewModel.addedToBuy?.title == "Added to To buy")
        #expect(viewModel.addedToBuy?.detail == "Septocaine 4% 1:100,000 · 6 cartridges")
        #expect(analytics.events == [.addedToBuy])
        viewModel.clearAddedToBuy()
        await viewModel.undoAddToBuy()
        #expect(repository.removals.count == 1)
        #expect(!viewModel.isOnToBuy)
        #expect(viewModel.addToBuyTitle == "Add to buy")
    }

    @Test func aProductAlreadyOnTheListDoesNotAddAgain() async {
        let repository = FakeProductDetailRepository(detailResult: .success(.demoSeptocaine(toBuyItemID: UUID())))
        let viewModel = make(repository: repository)
        await viewModel.load()
        #expect(viewModel.isOnToBuy)
        await viewModel.addToBuy()
        #expect(repository.adds.isEmpty)
    }

    @Test func aRefusedAddBecomesAToast() async {
        let repository = FakeProductDetailRepository()
        repository.addResult = .failure(AppError.readOnly)
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.addToBuy()
        #expect(viewModel.generalError == .readOnly)
        #expect(!viewModel.isOnToBuy)
        #expect(repository.detailCalls.count == 2, "A refused add reloads the detail, in case the list changed")
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }

    @Test func anUndoRowReadsTheEngineLabelOverItsReason() {
        let undone = StockTransaction(
            id: UUID(), type: .adjustment, delta: 2, quantityBefore: 52, quantityAfter: 54, reason: "Damaged",
            referenceLabel: "Undo · Damaged", at: Session.demoNow, byName: "Sarah Mitchell"
        )
        #expect(ProductDetailViewModel.label(for: undone) == "Undo · Damaged")
        #expect(ProductDetailViewModel.deltaText(for: undone, formatters: formatters) == "+2")
    }

    @Test func adjustOpensTheSheetOnTheLoadedProductOnly() async {
        let viewModel = make()
        viewModel.openAdjust()
        #expect(viewModel.sheet == nil, "Nothing loaded yet")
        #expect(viewModel.makeAdjustInventoryViewModel() == nil)
        await viewModel.load()
        viewModel.openAdjust()
        #expect(viewModel.sheet == .adjust)
        let sheet = viewModel.makeAdjustInventoryViewModel()
        #expect(sheet?.productName == "Septocaine 4% 1:100,000")
        #expect(sheet?.estimate == 54)
    }

    @Test func aSavedAdjustmentClosesTheSheetMovesTheFiguresAndQueuesTheToastWithUndo() async {
        let repository = FakeProductDetailRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(repository: repository, analytics: analytics)
        await viewModel.load()
        viewModel.openAdjust()
        let actionID = UUID()
        await viewModel.adjustmentSaved(.init(actionID: actionID, before: 54, after: 52, reason: .damaged))
        #expect(analytics.events == [.stockAdjusted(reason: .damaged, increase: false)])
        #expect(analytics.events.first?.payload == ["reason": .text("damaged"), "direction": .text("decrease")])
        #expect(viewModel.sheet == nil)
        #expect(viewModel.adjusted == .init(
            actionID: actionID, title: "Inventory adjusted", detail: "Septocaine 4% 1:100,000 · 54 → 52"
        ))
        #expect(repository.detailCalls.count == 2, "The fresh detail is loaded after the adjustment")
        viewModel.clearAdjusted()
        #expect(viewModel.adjusted == nil)
    }

    @Test func theFiguresMoveAtOnceWhenTheFreshDetailIsNotAvailable() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        await viewModel.load()
        repository.detailResult = .failure(AppError.network)
        await viewModel.adjustmentSaved(.init(actionID: nil, before: 54, after: 52, reason: .physicalCount))
        #expect(viewModel.availableText == "52")
        #expect(viewModel.detail?.unopened == 52)
        #expect(viewModel.state == .loaded, "The screen keeps what it has while offline")
        #expect(viewModel.adjusted?.actionID == nil, "A queued write offers no Undo")
    }

    @Test func undoReversesTheActionAndReloads() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        await viewModel.load()
        let actionID = UUID()
        await viewModel.adjustmentSaved(.init(actionID: actionID, before: 54, after: 52, reason: .damaged))
        viewModel.clearAdjusted()
        #expect(viewModel.undoableAdjustmentID == actionID, "The toast is shown and cleared before Undo is tapped")
        await viewModel.undoAdjustment()
        #expect(repository.undos == [actionID])
        #expect(viewModel.undoableAdjustmentID == nil)
        #expect(repository.detailCalls.count == 3)
        #expect(viewModel.generalError == nil)
        await viewModel.undoAdjustment()
        #expect(repository.undos.count == 1, "An adjustment is undone once")
    }

    @Test func undoWithoutAnActionIDDoesNothing() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.adjustmentSaved(.init(actionID: nil, before: 54, after: 52, reason: .missing))
        await viewModel.undoAdjustment()
        #expect(repository.undos.isEmpty)
    }

    @Test func aRefusedUndoBecomesAToast() async {
        let repository = FakeProductDetailRepository()
        repository.undoResult = .failure(AppError.validation(field: nil, message: "the undo window has passed"))
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.adjustmentSaved(.init(actionID: UUID(), before: 54, after: 52, reason: .damaged))
        await viewModel.undoAdjustment()
        #expect(viewModel.generalError == .validation(field: nil, message: "the undo window has passed"))
    }

    @Test func aFailureWithNothingCachedIsShown() async {
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .failure(AppError.network)))
        await viewModel.load()
        #expect(viewModel.state == .failed(.network))
        #expect(viewModel.detail == nil)
    }

    @Test func theLastDetailIsServedFromTheCacheWhenOffline() async {
        let cache = InMemoryResponseCache()
        let first = make(cache: cache)
        await first.load()
        let offline = FakeProductDetailRepository(detailResult: .failure(AppError.network))
        let relaunched = make(repository: offline, cache: cache)
        #expect(relaunched.detail?.name == "Septocaine 4% 1:100,000", "The cached detail shows before any load")
        await relaunched.load()
        #expect(relaunched.state == .loaded)
    }
}

extension ProductDetail {
    /// Septocaine with a few fields changed.
    nonisolated static func fixture(
        status: ProductStatus = .healthy,
        tracking: TrackingMode = .countable,
        categoryName: String? = "Anesthetic",
        packUnit: String? = "box",
        packSize: Int? = 50,
        quantity: Decimal = 54,
        unopened: Decimal = 54,
        openCount: Int = 0,
        minimum: Decimal? = nil,
        target: Decimal? = nil,
        lastCountedAt: Date? = Date(timeIntervalSince1970: 1_790_882_040),
        batches: [ProductBatch]? = nil,
        openBottles: [OpenBottle] = [],
        history: [StockTransaction]? = nil
    ) -> ProductDetail {
        let base = ProductDetail.demoSeptocaine()
        return ProductDetail(
            id: base.id, name: base.name, categoryName: categoryName, unit: base.unit, packUnit: packUnit,
            packSize: packSize, minimum: minimum ?? base.minimum, target: target ?? base.target, tracking: tracking,
            location: base.location, status: status, quantity: quantity, unopened: unopened, openCount: openCount,
            missingExpiryQuantity: 0, usedInLast30Days: base.usedInLast30Days, lastCountedAt: lastCountedAt,
            toBuyItemID: nil, batches: batches ?? base.batches, openBottles: openBottles,
            history: history ?? base.history, categoryID: base.categoryID, supplier: base.supplier
        )
    }
}
