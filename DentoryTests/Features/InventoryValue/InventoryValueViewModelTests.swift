import Foundation
import Testing
@testable import Dentory

/// Inventory value (f10): the total and its three figures, the categories with their shares, the top products, the
/// no-cost caption, the empty answer and the cache.
@MainActor
struct InventoryValueViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeInventoryValueRepository = FakeInventoryValueRepository(),
        cache: ResponseCaching = InMemoryResponseCache()
    ) -> InventoryValueViewModel {
        InventoryValueViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID
        )
    }

    /// A loaded view model answering `value`.
    private func loaded(_ value: InventoryValue) async -> InventoryValueViewModel {
        let viewModel = make(repository: FakeInventoryValueRepository(result: .success(value)))
        await viewModel.load()
        return viewModel
    }

    private func answer(
        total: Decimal = 12_420, atRisk90: Decimal = 186, uncostedCount: Int = 0,
        categories: [InventoryValueCategory] = InventoryValue.demo.categories,
        topProducts: [InventoryValueProduct] = InventoryValue.demo.topProducts
    ) -> InventoryValue {
        InventoryValue(
            total: total, atRisk90: atRisk90, used30: 2_140, received30: 1_890, uncostedCount: uncostedCount,
            categories: categories, topProducts: topProducts
        )
    }

    private func category(_ name: String?, _ value: Decimal) -> InventoryValueCategory {
        InventoryValueCategory(categoryID: name == nil ? nil : UUID(), name: name, value: value, productCount: 1)
    }

    @Test func loadsTheFiguresOfF10() async {
        let repository = FakeInventoryValueRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.state == .loading)
        #expect(viewModel.value == nil)
        #expect(viewModel.isEmpty == false, "Nothing to call empty before the first answer")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(repository.calls == [Session.demo.clinicID])
        #expect(viewModel.totalText == "$12,420")
        #expect(viewModel.stats.map(\.value) == ["$186", "$2,140", "$1,890"])
        #expect(viewModel.categories.map { viewModel.name(of: $0) } == [
            "Anesthetic", "Restorative", "Endodontics", "PPE", "Sterilization", "Other"
        ])
        #expect(viewModel.topProducts.map(\.name) == [
            "Septocaine 4% 1:100,000", "Composite A2", "Bonding agent", "Nitrile gloves M", "Endo file kit #15-40"
        ])
        #expect(viewModel.uncostedText == nil)
    }

    @Test func theFiguresReadAsDrawnAndAloud() async {
        let stats = await loaded(.demo).stats
        // The space before "d" never breaks, so a narrow column wraps "Expiring ≤" over "90 d".
        #expect(stats.map(\.label) == ["Expiring ≤ 90\u{00A0}d", "Used, 30\u{00A0}d", "Received, 30\u{00A0}d"])
        #expect(stats.map(\.spokenLabel) == [
            "Expiring within 90 days", "Used in the last 30 days", "Received in the last 30 days"
        ])
        #expect(stats.map(\.tone) == [.warning, nil, nil])
        let nothingAtRisk = await loaded(answer(atRisk90: 0)).stats
        #expect(nothingAtRisk.first?.value == "$0")
        #expect(nothingAtRisk.first?.tone == nil, "Nothing at risk stays in ink")
    }

    @Test func aCategoryShowsItsValueAndShareOfTheTotal() async throws {
        let viewModel = await loaded(.demo)
        let rows = viewModel.categories.map { (viewModel.valueText(of: $0), viewModel.shareText(of: $0)) }
        #expect(rows.map(\.0) == ["$4,860", "$2,410", "$2,180", "$1,540", "$830", "$600"])
        #expect(rows.map(\.1) == ["39%", "19%", "18%", "12%", "7%", "5%"])
        let anesthetic = try #require(viewModel.categories.first)
        #expect(abs(viewModel.share(of: anesthetic) - 4_860.0 / 12_420.0) < 0.000_1)
    }

    @Test func aSliverReadsUnderOnePercentAndBarsStayInside() async {
        let sliver = category("Impression", 12)
        let beyond = category("Anesthetic", 15_000)
        let viewModel = await loaded(answer(categories: [beyond, sliver]))
        #expect(viewModel.shareText(of: sliver) == "<1%")
        #expect(viewModel.shareText(of: beyond) == "100%", "Products below zero elsewhere cannot push a bar past full")
        #expect(viewModel.share(of: beyond) == 1)
        let noTotal = await loaded(answer(total: 0, categories: [sliver]))
        #expect(noTotal.share(of: sliver) == 0)
    }

    @Test func productsWithoutACategoryAreNamedButNotFiltered() async {
        let uncategorized = category(nil, 78)
        let viewModel = await loaded(answer(categories: [uncategorized]))
        #expect(viewModel.name(of: uncategorized) == "No category")
        #expect(viewModel.filter(for: uncategorized) == nil, "Inventory has no filter for them")
        #expect(uncategorized.id == "none")
        let anesthetic = InventoryValue.demo.categories[0]
        #expect(viewModel.filter(for: anesthetic) == "Anesthetic")
        #expect(anesthetic.id == "00000000-0000-4000-8000-0000000000c1")
    }

    @Test func aProductReadsQuantityTimesItsLastUnitCost() async {
        let viewModel = await loaded(.demo)
        let septocaine = InventoryValue.demo.topProducts[0]
        #expect(viewModel.line(for: septocaine) == "54 × $1.80")
        #expect(viewModel.valueText(of: septocaine) == "$97")
        let bibs = InventoryValueProduct(
            productID: UUID(), name: "Patient bib", unit: "bibs", quantity: 181, unitCost: Decimal(425) / 10_000,
            value: Decimal(769) / 100
        )
        #expect(viewModel.line(for: bibs) == "181 × $0.0425")
        #expect(viewModel.valueText(of: bibs) == "$8")
    }

    @Test func theCaptionCountsProductsInStockWithoutACost() async {
        #expect(await loaded(answer(uncostedCount: 0)).uncostedText == nil)
        #expect(await loaded(answer(uncostedCount: 1)).uncostedText == "1 product has no cost yet.")
        #expect(await loaded(answer(uncostedCount: 3)).uncostedText == "3 products have no cost yet.")
    }

    @Test func anAnswerWithNothingWorthListingIsEmpty() async {
        let viewModel = await loaded(answer(total: 0, atRisk90: 0, uncostedCount: 4, categories: [], topProducts: []))
        #expect(viewModel.isEmpty)
        #expect(viewModel.totalText == "$0")
        #expect(viewModel.uncostedText == "4 products have no cost yet.")
        #expect(InventoryValueViewModel.emptyText == "Nothing in stock has a cost yet.")
    }

    @Test func theLastAnswerShowsWhenTheNetworkIsGone() async {
        let cache = InMemoryResponseCache()
        await make(cache: cache).load()
        let offline = FakeInventoryValueRepository(result: .failure(AppError.network))
        let viewModel = make(repository: offline, cache: cache)
        #expect(viewModel.value == .demo, "The cached answer shows at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.value == .demo)
    }

    @Test func aFailureWithNothingCachedSaysWhy() async {
        let viewModel = make(repository: FakeInventoryValueRepository(result: .failure(AppError.network)))
        await viewModel.load()
        #expect(viewModel.state == .failed(.network))
        #expect(viewModel.value == nil)
    }

    @Test func aFreshAnswerReplacesTheCachedOne() async {
        let cache = InMemoryResponseCache()
        await make(cache: cache).load()
        let fresher = answer(total: 13_000)
        let viewModel = make(repository: FakeInventoryValueRepository(result: .success(fresher)), cache: cache)
        await viewModel.load()
        #expect(viewModel.totalText == "$13,000")
        #expect(make(cache: cache).value == fresher, "The new answer is cached")
    }
}
