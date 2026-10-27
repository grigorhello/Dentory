import Foundation
import Testing
@testable import Dentory

/// Count stock on the Inventory list (f18, MS-121): count mode, the review and discard sheets, the draft.
struct InventoryCountTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let septocaine = ProductSummary.demo[0]  // Healthy, 54 cartridges
    private let endoKit = ProductSummary.demo[1]     // Low, 1 kit
    private let bonding = ProductSummary.demo[3]     // Expiring, multi-use: 0 unopened, 1 open

    private func make(
        repository: FakeInventoryRepository = FakeInventoryRepository(),
        cache: ResponseCaching = InMemoryResponseCache(),
        draftStore: CountDraftStoring = InMemoryCountDraftStore(),
        formatters: ClinicFormatters? = nil,
        analytics: Analytics = NoopAnalytics(),
        userID: UUID = Session.demo.userID
    ) async -> InventoryListViewModel {
        let viewModel = InventoryListViewModel(
            repository: repository, cache: cache, draftStore: draftStore, formatters: formatters ?? self.formatters,
            clinicID: Session.demo.clinicID, userID: userID, analytics: analytics
        )
        await viewModel.load()
        return viewModel
    }

    /// Endo file kit under Low, Septocaine under Healthy, Bonding agent found by search.
    private func countThreeInDifferentFilters(_ viewModel: InventoryListViewModel) {
        viewModel.startCount()
        viewModel.apply(filter: .low)
        viewModel.setCount(3, for: endoKit)
        viewModel.apply(filter: .healthy)
        viewModel.setCount(52, for: septocaine)
        viewModel.apply(filter: .all)
        viewModel.searchText = "bond"
        viewModel.setCount(1, for: bonding)
        viewModel.searchText = ""
    }

    @Test func countStockTurnsTheListIntoCountMode() async {
        let viewModel = await make()
        #expect(viewModel.title == "Inventory")
        #expect(viewModel.isCounting == false)
        viewModel.startCount()
        #expect(viewModel.isCounting)
        #expect(viewModel.title == "Count")
        #expect(viewModel.reviewTitle == "Review count")
        #expect(viewModel.corrections.isEmpty, "Review stays disabled until a quantity changed")
        #expect(viewModel.countValue(for: septocaine) == 54)
        #expect(viewModel.isCorrected(septocaine) == false)
        viewModel.reviewCount()
        #expect(viewModel.countSheet == nil)
    }

    @Test func rowsReadTheEstimateAndWhereTheProductSits() async {
        let unplaced = ProductSummary(
            id: UUID(), name: "Paper points", categoryName: "Endodontics", unit: "packs", tracking: .countable,
            location: nil, quantity: 6, unopened: 6, openCount: 0, minimum: 2, status: .healthy
        )
        let repository = FakeInventoryRepository(result: .success(ProductSummary.demo + [unplaced]))
        let viewModel = await make(repository: repository)
        viewModel.startCount()
        // The location's own dot keeps its line too, as every caption's does (#207 review).
        #expect(viewModel.countLine(for: septocaine) == "est. 54 cartridges\u{00A0}· Operatory 1\u{00A0}· Drawer A")
        #expect(viewModel.countLine(for: bonding) == "Count unopened only\u{00A0}· Operatory 1\u{00A0}· Drawer C")
        #expect(viewModel.countLine(for: unplaced) == "est. 6 packs")
    }

    @Test func countsPersistWhileFilteringAndTheReviewButtonCountsThem() async {
        let viewModel = await make()
        viewModel.startCount()
        viewModel.setCount(52, for: septocaine)
        #expect(viewModel.isCorrected(septocaine))
        #expect(viewModel.reviewTitle == "Review · 1 correction")
        viewModel.setCount(54, for: septocaine)
        #expect(viewModel.reviewTitle == "Review count", "Back at the estimate is no correction")
        countThreeInDifferentFilters(viewModel)
        #expect(viewModel.visibleProducts.count == ProductSummary.demo.count)
        #expect(viewModel.corrections.map(\.name) == [endoKit.name, bonding.name, septocaine.name], "In list order")
        #expect(viewModel.reviewTitle == "Review · 3 corrections")
        #expect(viewModel.countValue(for: endoKit) == 3)
    }

    @Test func reviewShowsEachChangeAndUndoPutsARowBack() async {
        let viewModel = await make()
        viewModel.startCount()
        viewModel.setCount(52, for: septocaine)
        viewModel.setCount(1, for: bonding)
        viewModel.reviewCount()
        #expect(viewModel.countSheet == .review)
        #expect(viewModel.correctionLine(for: septocaine) == "54 → 52")
        #expect(viewModel.correctionTone(for: septocaine) == .danger)
        #expect(viewModel.correctionLine(for: bonding) == "0 → 1 unopened")
        #expect(viewModel.correctionTone(for: bonding) == .success)
        #expect(viewModel.applyTitle == "Apply count · 2 corrections")
        viewModel.undoCorrection(septocaine)
        #expect(viewModel.corrections.map(\.name) == [bonding.name])
        #expect(viewModel.countValue(for: septocaine) == 54)
        #expect(viewModel.applyTitle == "Apply count · 1 correction")
        viewModel.undoCorrection(bonding)
        #expect(viewModel.corrections.isEmpty, "Apply is disabled once every row is undone")
        viewModel.closeCountSheet()
        #expect(viewModel.countSheet == nil)
        #expect(viewModel.isCounting, "Back to counting keeps the count")
    }

    @Test func applyWritesOneLinePerCorrectionAndReturnsToBrowsing() async {
        let repository = FakeInventoryRepository()
        let draftStore = InMemoryCountDraftStore()
        let viewModel = await make(repository: repository, draftStore: draftStore)
        countThreeInDifferentFilters(viewModel)
        viewModel.reviewCount()
        await viewModel.applyCount()
        #expect(repository.applies == [FakeInventoryRepository.Apply(
            clinicID: Session.demo.clinicID,
            counts: [
                CountedQuantity(productID: endoKit.id, counted: 3),
                CountedQuantity(productID: bonding.id, counted: 1),
                CountedQuantity(productID: septocaine.id, counted: 52)
            ]
        )])
        #expect(viewModel.countApplied == .init(title: "Count applied", detail: "3 products updated"))
        #expect(viewModel.isCounting == false)
        #expect(viewModel.countSheet == nil)
        #expect(viewModel.title == "Inventory")
        #expect(draftStore.load() == nil, "The draft is gone once applied")
        #expect(repository.calls.count == 2, "The list reloads for the server's status")
        viewModel.clearCountApplied()
        #expect(viewModel.countApplied == nil)
    }

    /// The cached list follows the counted figures, so a count queued offline does not come back on the next visit.
    @Test func aCountAppliedOfflineShowsTheCountedFigures() async {
        let repository = FakeInventoryRepository()
        let cache = InMemoryResponseCache()
        let viewModel = await make(repository: repository, cache: cache)
        countThreeInDifferentFilters(viewModel)
        repository.applyResult = .success(.queued)
        repository.result = .failure(AppError.network)
        await viewModel.applyCount()
        #expect(viewModel.countApplied?.detail == "3 products updated")
        let figures = viewModel.products.filter { [septocaine.id, bonding.id].contains($0.id) }.map(\.quantity)
        #expect(figures == [52, 2], "Septocaine shows 52; Bonding 1 unopened plus its open bottle")
        let nextVisit = await make(repository: repository, cache: cache)
        let cached = nextVisit.products.filter { [septocaine.id, bonding.id].contains($0.id) }.map(\.quantity)
        #expect(cached == [52, 2], "The next visit reads the counted figures from the cache")
    }

    /// MS-150: the stock change of the count itself (`WriteCoordinator.appliedWrites`) arrives while the count is being
    /// written and is left to the reload after the write, so Apply count reads the list once, not twice.
    @Test func applyingACountReadsTheListOnce() async {
        let repository = FakeInventoryRepository()
        let viewModel = await make(repository: repository)
        countThreeInDifferentFilters(viewModel)
        repository.onApply = { await viewModel.stockChanged() }
        await viewModel.applyCount()
        #expect(repository.applies.count == 1)
        #expect(repository.calls.count == 2, "The first load, then one for the server's status")
        await viewModel.stockChanged()
        #expect(repository.calls.count == 3, "A later stock change reloads")
    }

    /// A count queued offline is not followed by a reload, which would show the figures from before it: its replay is
    /// a stock change of its own, which reloads.
    @Test func aQueuedCountReloadsOnceReplayed() async {
        let repository = FakeInventoryRepository()
        let viewModel = await make(repository: repository)
        countThreeInDifferentFilters(viewModel)
        repository.applyResult = .success(.queued)
        await viewModel.applyCount()
        #expect(repository.calls.count == 1)
        #expect(viewModel.products.first { $0.id == septocaine.id }?.quantity == 52)
        #expect(viewModel.visibleProducts.first?.name == "Rubber dam latex-free", "Still in list order")
        await viewModel.stockChanged()
        #expect(repository.calls.count == 2)
    }

    /// MS-147: `inv.count.review` with the corrections applied and the seconds from Count stock to Apply count, the
    /// start kept in the draft across a relaunch.
    @Test func anAppliedCountIsCountedWithItsCorrectionsAndSeconds() async {
        let clock = MovingClock(Session.demoNow)
        let moving = ClinicFormatters(
            currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
            locale: Locale(identifier: "en_US"), clock: clock
        )
        let draftStore = InMemoryCountDraftStore()
        let first = await make(draftStore: draftStore, formatters: moving)
        countThreeInDifferentFilters(first)
        clock.now = Session.demoNow.addingTimeInterval(95)
        let analytics = SpyAnalytics()
        let relaunched = await make(draftStore: draftStore, formatters: moving, analytics: analytics)
        relaunched.reviewCount()
        await relaunched.applyCount()
        #expect(analytics.events == [.countApplied(corrections: 3, seconds: 95)])
        #expect(analytics.events.first?.payload == ["item_count": .number(3), "duration_s": .number(95)])
    }

    /// A read-only clinic's database refuses the count (MS-142): the sheet says so and nothing is counted as applied.
    @Test func aRefusedCountStaysOnTheReviewSheet() async {
        let repository = FakeInventoryRepository()
        let draftStore = InMemoryCountDraftStore()
        let analytics = SpyAnalytics()
        let viewModel = await make(repository: repository, draftStore: draftStore, analytics: analytics)
        viewModel.startCount()
        viewModel.setCount(52, for: septocaine)
        viewModel.reviewCount()
        repository.applyResult = .failure(AppError.readOnly)
        await viewModel.applyCount()
        #expect(viewModel.countError == .readOnly)
        #expect(viewModel.countSheet == .review)
        #expect(viewModel.isCounting)
        #expect(viewModel.countApplied == nil)
        #expect(analytics.events.isEmpty, "A refused count is not counted")
        #expect(draftStore.load()?.counted == [septocaine.id: 52], "The counts are kept")
        viewModel.closeCountSheet()
        viewModel.reviewCount()
        #expect(viewModel.countError == nil, "Opening the review again starts clean")
    }

    @Test func cancelWithoutChangesLeavesAtOnce() async {
        let draftStore = InMemoryCountDraftStore()
        let viewModel = await make(draftStore: draftStore)
        viewModel.startCount()
        viewModel.setCount(54, for: septocaine)
        viewModel.cancelCount()
        #expect(viewModel.isCounting == false)
        #expect(viewModel.countSheet == nil)
        #expect(draftStore.load() == nil)
    }

    @Test func cancelWithChangesAsksBeforeDiscarding() async {
        let repository = FakeInventoryRepository()
        let draftStore = InMemoryCountDraftStore()
        let viewModel = await make(repository: repository, draftStore: draftStore)
        viewModel.startCount()
        viewModel.setCount(52, for: septocaine)
        viewModel.cancelCount()
        #expect(viewModel.countSheet == .discard)
        #expect(viewModel.discardMessage == "1 change. Inventory stays as it is.")
        viewModel.closeCountSheet()
        #expect(viewModel.isCounting, "Keep counting")
        viewModel.setCount(3, for: endoKit)
        viewModel.cancelCount()
        #expect(viewModel.discardMessage == "2 changes. Inventory stays as it is.")
        viewModel.discardCount()
        #expect(viewModel.isCounting == false)
        #expect(viewModel.countSheet == nil)
        #expect(draftStore.load() == nil)
        #expect(repository.applies.isEmpty, "Nothing is written")
        viewModel.startCount()
        #expect(viewModel.countValue(for: septocaine) == 54, "A new count starts from the estimates")
    }

    @Test func theDraftBringsTheCountBackAfterTheAppWasClosed() async {
        let draftStore = InMemoryCountDraftStore()
        let first = await make(draftStore: draftStore)
        first.startCount()
        first.setCount(52, for: septocaine)
        let relaunched = await make(draftStore: draftStore)
        #expect(relaunched.isCounting)
        #expect(relaunched.countValue(for: septocaine) == 52)
        #expect(relaunched.reviewTitle == "Review · 1 correction")
    }

    @Test func someoneElsesDraftIsNotOpened() async {
        let draft = StockCount(clinicID: Session.demo.clinicID, userID: UUID(), counted: [septocaine.id: 52])
        let viewModel = await make(draftStore: InMemoryCountDraftStore(draft: draft))
        #expect(viewModel.isCounting == false)
    }

    @Test func theToastCountsProductsInTheSingularToo() {
        #expect(InventoryListViewModel.productsUpdated(1) == "1 product updated")
        #expect(InventoryListViewModel.productsUpdated(4) == "4 products updated")
    }
}
