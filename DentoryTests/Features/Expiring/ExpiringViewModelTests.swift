import Foundation
import Testing
@testable import Dentory

/// Expiring soon (f27, f28): the windows, the summary, each card's lines, Mark disposed with its Undo, the cache.
struct ExpiringViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let bonding = ExpiringBatch.demo[0]
    private let septocaine = ExpiringBatch.demo[1]

    private func make(
        _ repository: FakeExpiringRepository = FakeExpiringRepository(), isAdmin: Bool = true, window: Int? = nil,
        cache: ResponseCaching = InMemoryResponseCache(), analytics: SpyAnalytics = SpyAnalytics()
    ) async -> ExpiringViewModel {
        let viewModel = ExpiringViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            isAdmin: isAdmin, window: window, analytics: analytics
        )
        await viewModel.load()
        return viewModel
    }

    private func batch(
        _ name: String, quantity: Decimal, unit: String = "packs", lot: String? = nil, month: CalendarDay,
        value: Decimal = 10
    ) -> ExpiringBatch {
        ExpiringBatch(
            id: UUID(), productID: UUID(), name: name, unit: unit, tracking: .countable, quantity: quantity, lot: lot,
            expiryMonth: month, value: value
        )
    }

    @Test func theClinicWindowListsF27sTwoBatches() async {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.window == 90)
        #expect(viewModel.windowOptions.map(\.text) == ["30 days", "60 days", "90 days"])
        #expect(viewModel.batches.map(\.name) == ["Bonding agent", "Septocaine 4% 1:100,000"])
        #expect(viewModel.summary == "2 products\u{00A0}· $186 at risk within 90 days.")
    }

    @Test func eachCardSaysWhatTheBatchHoldsAndWhenItGoes() async {
        let viewModel = await make()
        #expect(viewModel.line(for: bonding) == "1 bottle\u{00A0}· lot BA7\u{00A0}· Nov 2026")
        #expect(viewModel.line(for: septocaine) == "34 cartridges\u{00A0}· lot B441\u{00A0}· Dec 2026")
        #expect(viewModel.daysText(for: bonding) == "59 days")
        #expect(viewModel.daysText(for: septocaine) == "90 days")
        #expect(viewModel.daysTone(for: bonding) == .warning)
        #expect(viewModel.valueText(for: bonding) == "$82")
        #expect(viewModel.valueText(for: septocaine) == "$104")
        let undated = batch("Gauze", quantity: 2, month: CalendarDay(year: 2026, month: 12, day: 1))
        #expect(viewModel.line(for: undated) == "2 packs\u{00A0}· Dec 2026", "No lot, no lot part")
    }

    @Test func daysReadExpiredTodayAndOneDayInDanger() async {
        let viewModel = await make()
        let expired = batch("Etch gel 37%", quantity: 3, month: CalendarDay(year: 2026, month: 9, day: 1))
        let thisMonth = batch("Prophy paste", quantity: 1, month: CalendarDay(year: 2026, month: 10, day: 1))
        #expect(viewModel.daysText(for: expired) == "Expired")
        #expect(viewModel.daysTone(for: expired) == .danger)
        #expect(viewModel.daysText(for: thisMonth) == "29 days")
        #expect(viewModel.daysTone(for: thisMonth) == .danger, "Within 30 days")
    }

    @Test func aNarrowerWindowFiltersWithoutAnotherRead() async {
        let repository = FakeExpiringRepository()
        let viewModel = await make(repository)
        viewModel.window = 60
        #expect(viewModel.batches.map(\.name) == ["Bonding agent"])
        #expect(viewModel.summary == "1 product\u{00A0}· $82 at risk within 60 days.")
        viewModel.window = 30
        #expect(viewModel.batches.isEmpty)
        #expect(viewModel.summary == nil, "The empty state takes its place")
        #expect(ExpiringViewModel.emptyText == "Nothing expires in this window.")
        #expect(repository.listCalls == 1)
    }

    @Test func expiredBatchesShowInEveryWindowAndTwoBatchesOfOneProductCountOnce() async {
        let repository = FakeExpiringRepository()
        let expired = ExpiringBatch(
            id: UUID(), productID: septocaine.productID, name: septocaine.name, unit: "cartridges",
            tracking: .countable, quantity: 4, lot: "A001", expiryMonth: CalendarDay(year: 2026, month: 8, day: 1),
            value: 12
        )
        repository.listResult = .success(ExpiringList(window: 90, batches: [expired] + ExpiringBatch.demo))
        let viewModel = await make(repository, window: 30)
        #expect(viewModel.window == 30, "Home's tiles and alerts pick the window")
        #expect(viewModel.batches.map(\.lot) == ["A001"])
        viewModel.window = 90
        #expect(viewModel.summary == "2 products\u{00A0}· $198 at risk within 90 days.")
    }

    /// A segment picked before the list arrives, or while it cannot, stays picked once the list comes.
    @Test func aSegmentPickedBeforeTheListArrivesStays() async {
        let repository = FakeExpiringRepository()
        repository.listResult = .failure(AppError.network)
        let viewModel = await make(repository)
        viewModel.window = 60
        repository.listResult = .success(ExpiringList(window: 90, batches: ExpiringBatch.demo))
        await viewModel.load()
        #expect(viewModel.window == 60, "The clinic's own window does not override the choice")
        #expect(viewModel.batches.map(\.name) == ["Bonding agent"])
    }

    @Test func staffSeeTheListButCannotDispose() async {
        let viewModel = await make(isAdmin: false)
        #expect(viewModel.batches.count == 2)
        viewModel.askToDispose(bonding)
        #expect(viewModel.disposing == nil)
    }

    @Test func disposingTheWholeBatchRemovesTheCardAndOffersUndo() async throws {
        let repository = FakeExpiringRepository()
        let analytics = SpyAnalytics()
        let viewModel = await make(repository, analytics: analytics)
        viewModel.askToDispose(septocaine)
        #expect(viewModel.disposing == septocaine)
        let actionID = UUID()
        repository.listResult = .success(ExpiringList(window: 90, batches: [bonding]))
        await viewModel.disposed(.init(batch: septocaine, quantity: 34, actionID: actionID))
        #expect(viewModel.disposing == nil)
        #expect(analytics.events == [.batchDisposed], "MS-147")
        #expect(viewModel.batches.map(\.name) == ["Bonding agent"])
        #expect(viewModel.summary == "1 product\u{00A0}· $82 at risk within 90 days.")
        #expect(viewModel.message == .init(
            title: "Disposed", detail: "34 cartridges Septocaine 4% 1:100,000", undoActionID: actionID
        ))
        repository.listResult = .success(ExpiringList(window: 90, batches: ExpiringBatch.demo))
        await viewModel.undoDisposal(actionID)
        #expect(repository.undone == [actionID])
        #expect(viewModel.batches.count == 2, "Undo brings the card back")
    }

    @Test func disposingPartOfABatchKeepsTheRest() async {
        let repository = FakeExpiringRepository()
        repository.listResult = .failure(AppError.network)
        let viewModel = ExpiringViewModel(
            repository: repository, cache: InMemoryResponseCache(), formatters: formatters,
            clinicID: Session.demo.clinicID, isAdmin: true, analytics: SpyAnalytics()
        )
        repository.listResult = .success(ExpiringList(window: 90, batches: ExpiringBatch.demo))
        await viewModel.load()
        repository.listResult = .failure(AppError.network)
        await viewModel.disposed(.init(batch: septocaine, quantity: 10, actionID: nil))
        #expect(viewModel.batches.last?.quantity == 24, "Shown at once, even while the reload fails")
        #expect(viewModel.message?.undoActionID == nil, "Queued offline: nothing to undo yet")
        #expect(viewModel.state == .loaded)
    }

    /// MS-132 review note: a disposal queued offline stays off the list on the next visit, so it is not disposed twice.
    @Test func aDisposalQueuedOfflineStaysOffTheCachedList() async {
        let cache = InMemoryResponseCache()
        let repository = FakeExpiringRepository()
        let viewModel = await make(repository, cache: cache)
        repository.listResult = .failure(AppError.network)
        await viewModel.disposed(.init(batch: septocaine, quantity: 34, actionID: nil))
        let nextVisit = ExpiringViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            isAdmin: true, analytics: SpyAnalytics()
        )
        #expect(!nextVisit.batches.contains { $0.id == septocaine.id }, "The cached list has the disposal")
        #expect(nextVisit.batches.count == 1)
    }

    @Test func offlineTheLastListShowsFromTheCache() async {
        let cache = InMemoryResponseCache()
        _ = await make(cache: cache)
        let offline = FakeExpiringRepository()
        offline.listResult = .failure(AppError.network)
        let viewModel = ExpiringViewModel(
            repository: offline, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID, isAdmin: true,
            analytics: SpyAnalytics()
        )
        #expect(viewModel.batches.count == 2, "The cached list shows at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
    }

    @Test func withoutAnyListTheErrorShows() async {
        let repository = FakeExpiringRepository()
        repository.listResult = .failure(AppError.network)
        let viewModel = await make(repository)
        #expect(viewModel.state == .failed(.network))
    }

    @Test func aFailedUndoIsAToast() async {
        let repository = FakeExpiringRepository()
        repository.undoError = AppError.validation(field: nil, message: "the undo window has passed")
        let viewModel = await make(repository)
        await viewModel.undoDisposal(UUID())
        #expect(viewModel.generalError == .validation(field: nil, message: "the undo window has passed"))
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }
}
