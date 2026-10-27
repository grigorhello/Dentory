import Foundation
import Testing
@testable import Dentory

@MainActor
struct InventoryListViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeInventoryRepository = FakeInventoryRepository(),
        cache: ResponseCaching = InMemoryResponseCache(),
        filter: InventoryFilter = .all,
        category: String? = nil
    ) -> InventoryListViewModel {
        InventoryListViewModel(
            repository: repository, cache: cache, draftStore: InMemoryCountDraftStore(), formatters: formatters,
            clinicID: Session.demo.clinicID, userID: Session.demo.userID, analytics: NoopAnalytics(), filter: filter,
            category: category
        )
    }

    private func names(_ viewModel: InventoryListViewModel) -> [String] {
        viewModel.visibleProducts.map(\.name)
    }

    @Test func loadsTheClinicsProductsSortedByStatusPriorityThenName() async {
        let repository = FakeInventoryRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.state == .loading)
        #expect(viewModel.emptyReason == nil, "Nothing to say before the first answer")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(repository.calls == [Session.demo.clinicID])
        #expect(names(viewModel) == [
            "Rubber dam latex-free",
            "Composite A2", "Endo file kit #15-40", "Root canal sealer", "Temporary cement",
            "Bonding agent",
            "Gutta percha F2",
            "Alginate impression", "Nitrile gloves M", "Septocaine 4% 1:100,000", "Suction tips", "Surface disinfectant"
        ])
    }

    @Test func lowIncludesOutOfStockAndTheOtherChipsMatchOneStatus() async {
        let viewModel = make()
        await viewModel.load()
        viewModel.filter = .low
        #expect(names(viewModel) == [
            "Rubber dam latex-free", "Composite A2", "Endo file kit #15-40", "Root canal sealer", "Temporary cement"
        ])
        viewModel.filter = .expiring
        #expect(names(viewModel) == ["Bonding agent"])
        viewModel.filter = .missingExpiry
        #expect(names(viewModel) == ["Gutta percha F2"])
        viewModel.filter = .healthy
        #expect(names(viewModel).count == 5)
    }

    @Test func searchIgnoresCaseAndAccentsAndCombinesWithTheChip() async {
        let viewModel = make()
        await viewModel.load()
        viewModel.searchText = "  COMPOSITE "
        #expect(names(viewModel) == ["Composite A2"])
        viewModel.searchText = "séptocaine"
        #expect(names(viewModel) == ["Septocaine 4% 1:100,000"])
        viewModel.filter = .low
        #expect(names(viewModel).isEmpty)
        #expect(viewModel.emptyReason == .noMatches)
        viewModel.searchText = ""
        #expect(viewModel.emptyReason == nil)
    }

    @Test func aCategoryNarrowsTheListUntilItIsCleared() async {
        let viewModel = make(category: "Endodontics")
        await viewModel.load()
        #expect(viewModel.category == "Endodontics")
        #expect(names(viewModel) == [
            "Rubber dam latex-free", "Endo file kit #15-40", "Root canal sealer", "Gutta percha F2"
        ])
        viewModel.filter = .low
        #expect(names(viewModel) == ["Rubber dam latex-free", "Endo file kit #15-40", "Root canal sealer"])
        viewModel.clearCategory()
        #expect(viewModel.category == nil)
        #expect(names(viewModel).count == 5)
        viewModel.apply(category: "PPE")
        viewModel.filter = .all
        #expect(names(viewModel) == ["Nitrile gloves M"])
    }

    @Test func homeCanPreselectAChip() async {
        let viewModel = make(filter: .missingExpiry)
        await viewModel.load()
        #expect(names(viewModel) == ["Gutta percha F2"])
        viewModel.apply(filter: .all)
        #expect(names(viewModel).count == 12)
    }

    @Test func captionsReadFiguresThenCategory() async {
        let viewModel = make()
        await viewModel.load()
        func caption(_ name: String) -> String? {
            viewModel.products.first { $0.name == name }.map(viewModel.caption(for:))
        }
        #expect(caption("Septocaine 4% 1:100,000") == "54 cartridges\u{00A0}· Anesthetic")
        #expect(caption("Surface disinfectant") == "1 unopened\u{00A0}· 2 open\u{00A0}· Sterilization")
        #expect(caption("Rubber dam latex-free") == "0 sheets\u{00A0}· Endodontics")
        let uncategorised = ProductSummary(
            id: UUID(), name: "Gauze", categoryName: nil, unit: "packs", tracking: .countable, location: nil,
            quantity: 2.5, unopened: 2.5, openCount: 0, minimum: 4, status: .low
        )
        #expect(viewModel.caption(for: uncategorised) == "2.5 packs")
    }

    @Test func anEmptyClinicSaysSoOnlyOnceLoaded() async {
        let viewModel = make(repository: FakeInventoryRepository(result: .success([])))
        #expect(viewModel.emptyReason == nil)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.emptyReason == .noProducts)
    }

    @Test func aFailureWithNothingCachedIsShown() async {
        let viewModel = make(repository: FakeInventoryRepository(result: .failure(AppError.network)))
        await viewModel.load()
        #expect(viewModel.state == .failed(.network))
        #expect(viewModel.products.isEmpty)
        #expect(viewModel.emptyReason == nil, "The failure notice shows, not an empty state")
    }

    @Test func theLastListIsServedFromTheCacheWhenOffline() async {
        let cache = InMemoryResponseCache()
        let first = make(cache: cache)
        await first.load()

        let relaunched = make(repository: FakeInventoryRepository(result: .failure(AppError.network)), cache: cache)
        #expect(relaunched.products.count == 12, "The cached rows show before any load")
        await relaunched.load()
        #expect(relaunched.state == .loaded)
        #expect(relaunched.products.count == 12)
    }

    /// MS-150: the list is sorted once per answer and the rows only filter it, so the cached rows are in list order
    /// before any load.
    @Test func theCachedRowsAreInListOrder() async {
        let cache = InMemoryResponseCache()
        let first = make(cache: cache)
        await first.load()
        let relaunched = make(repository: FakeInventoryRepository(result: .failure(AppError.network)), cache: cache)
        #expect(names(relaunched) == names(first))
        #expect(names(relaunched).first == "Rubber dam latex-free")
        #expect(names(relaunched).last == "Surface disinfectant")
    }
}
