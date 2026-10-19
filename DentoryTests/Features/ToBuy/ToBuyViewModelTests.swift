import Foundation
import Testing
@testable import Dentory

/// To buy (f25, f26): the segments, the lines, quantities, the admin's selection and Mark as ordered, Remove and
/// Add item.
struct ToBuyViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let demo = ToBuyItem.demo(now: Session.demoNow)

    private func make(
        _ repository: FakeToBuyRepository = FakeToBuyRepository(), isAdmin: Bool = true,
        cache: ResponseCaching = InMemoryResponseCache()
    ) async -> ToBuyViewModel {
        let viewModel = ToBuyViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            isAdmin: isAdmin, saveDelay: .seconds(60)
        )
        await viewModel.load()
        return viewModel
    }

    private func line(_ name: String) throws -> ToBuyItem {
        try #require(demo.first { $0.name == name })
    }

    private func product(_ name: String) throws -> ProductSummary {
        try #require((ProductSummary.demo + DemoSupplies.extraProducts).first { $0.name == name })
    }

    @Test func theListSplitsIntoItsSegments() async {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.toBuy.map(\.name) == ["Endo file kit #15-40", "Composite A2", "Rubber dam latex-free"])
        #expect(viewModel.ordered.count == 5)
        #expect(viewModel.received.map(\.name) == ["Alginate impression"])
        #expect(viewModel.segmentOptions.map(\.text) == ["To buy · 3", "Ordered · 5", "Received · 1"])
        #expect(viewModel.toBuyCount == 3, "The tab's badge")
        #expect(viewModel.rows == viewModel.toBuy)
        viewModel.segment = .ordered
        #expect(viewModel.rows == viewModel.ordered)
    }

    @Test func eachLineSaysWhereItStands() async throws {
        let viewModel = await make()
        #expect(viewModel.line(for: try line("Endo file kit #15-40")) == "Current 1 · target 5 · Patterson")
        #expect(viewModel.line(for: try line("Gauze")) == "5 ordered Oct 1 · Patterson")
        #expect(viewModel.line(for: try line("Alginate impression")) == "Received Sep 26 · Patterson")
        let endo = try line("Endo file kit #15-40")
        let noSupplier = ToBuyItem(
            id: UUID(), productID: endo.productID, name: endo.name, unit: endo.unit, supplier: nil,
            quantity: 1, target: 5, buyQuantity: 4, source: .manual, status: .toBuy, createdAt: Session.demoNow,
            orderedAt: nil, receivedAt: nil
        )
        #expect(viewModel.line(for: noSupplier) == "Current 1 · target 5", "The supplier only when known")
    }

    @Test func everyLineStartsSelectedAndClearUnticksThemAll() async throws {
        let viewModel = await make()
        #expect(viewModel.showsSelection)
        #expect(viewModel.showsMarkOrdered)
        #expect(viewModel.selectionSummary == "3 of 3 selected")
        #expect(viewModel.selectionAction == "Clear")
        #expect(viewModel.markOrderedTitle == "Mark 3 as ordered")
        viewModel[isSelected: try line("Rubber dam latex-free").id] = false
        #expect(viewModel.selectionSummary == "2 of 3 selected")
        #expect(viewModel.markOrderedTitle == "Mark 2 as ordered")
        viewModel.toggleAll()
        #expect(viewModel.selectionSummary == "0 of 3 selected")
        #expect(viewModel.selectionAction == "Select all")
        #expect(!viewModel.canMarkOrdered, "Disabled only when nothing is selected")
        viewModel.toggleAll()
        #expect(viewModel.selectionSummary == "3 of 3 selected")
    }

    @Test func staffHaveNoSelectionAndCannotMarkOrdered() async {
        let repository = FakeToBuyRepository()
        let viewModel = await make(repository, isAdmin: false)
        #expect(!viewModel.showsSelection)
        #expect(!viewModel.showsMarkOrdered, "Hidden by role, never shown disabled")
        #expect(!viewModel.canMarkOrdered)
        await viewModel.markOrdered()
        #expect(repository.orders.isEmpty)
    }

    @Test func withNothingLeftToBuyMarkOrderedStaysDisabledForTheAdmin() async {
        let repository = FakeToBuyRepository()
        repository.itemsResult = .success(demo.filter { $0.status != .toBuy })
        let viewModel = await make(repository)
        #expect(viewModel.toBuy.isEmpty)
        #expect(viewModel.showsMarkOrdered, "Disabled only when 0 selected, never hidden")
        #expect(!viewModel.canMarkOrdered)
        #expect(!viewModel.showsSelection, "No selection bar over an empty list")
        viewModel.segment = .ordered
        #expect(!viewModel.showsMarkOrdered, "Only on the To buy segment")
    }

    @Test func aRunOfTapsIsSavedOnceAndNeverBelowOne() async throws {
        let repository = FakeToBuyRepository()
        let viewModel = await make(repository)
        let endo = try line("Endo file kit #15-40").id
        viewModel[quantityOf: endo] = 5
        viewModel[quantityOf: endo] = 6
        #expect(viewModel[quantityOf: endo] == 6)
        #expect(repository.quantities.isEmpty, "Nothing is sent while the taps go on")
        await viewModel.flushPendingSaves()
        #expect(repository.quantities.map(\.1) == [6])
        viewModel[quantityOf: endo] = 0
        #expect(viewModel[quantityOf: endo] == 1)
        let gauze = try line("Gauze").id
        viewModel[quantityOf: gauze] = 9
        #expect(viewModel[quantityOf: gauze] == 5, "An ordered line keeps its quantity")
    }

    @Test func aReloadKeepsAQuantityNotSavedYet() async throws {
        let viewModel = await make()
        let endo = try line("Endo file kit #15-40").id
        viewModel[quantityOf: endo] = 9
        await viewModel.load()
        #expect(viewModel[quantityOf: endo] == 9)
    }

    @Test func markOrderedSavesPendingQuantitiesThenMovesTheSelection() async throws {
        let repository = FakeToBuyRepository()
        let viewModel = await make(repository)
        let endo = try line("Endo file kit #15-40").id
        let composite = try line("Composite A2").id
        viewModel[quantityOf: endo] = 6
        viewModel[isSelected: try line("Rubber dam latex-free").id] = false
        await viewModel.markOrdered()
        #expect(repository.log == ["quantity", "ordered"])
        #expect(repository.orders == [[endo, composite]])
        #expect(viewModel.message == .init(title: "Marked as ordered", detail: "2 items", undoItemID: nil))
        #expect(repository.itemCalls == 2, "The list reloads")
    }

    @Test func aRefusedMarkOrderedIsAToast() async {
        let repository = FakeToBuyRepository()
        repository.markOrderedResult = .failure(AppError.forbidden)
        let viewModel = await make(repository)
        await viewModel.markOrdered()
        #expect(viewModel.generalError == .forbidden)
        #expect(viewModel.message == nil)
    }

    @Test func removeTakesTheLineOffAndARefusalPutsItBack() async throws {
        let repository = FakeToBuyRepository()
        let viewModel = await make(repository)
        let endo = try line("Endo file kit #15-40").id
        await viewModel.remove(endo)
        #expect(repository.removals == [endo])
        #expect(viewModel.toBuy.count == 2)
        #expect(viewModel.toBuyCount == 2)

        repository.removeError = AppError.forbidden
        let composite = try line("Composite A2").id
        await viewModel.remove(composite)
        #expect(viewModel.toBuy.map(\.id).contains(composite), "Back on the list")
        #expect(viewModel.generalError == .forbidden)
    }

    @Test func addItemOffersWhatIsNotOnTheListYet() async throws {
        let viewModel = await make()
        viewModel.openAddItem()
        #expect(viewModel.sheet == .addItem)
        #expect(viewModel.addItemEmptyText.isEmpty)
        await viewModel.loadProducts()
        let names = viewModel.addableProducts.map(\.name)
        #expect(!names.contains("Endo file kit #15-40") && !names.contains("Rubber dam latex-free"))
        #expect(names.contains("Gauze"), "An ordered product can be added again")
        #expect(viewModel.addCaption(for: try product("Gauze")) == "8 packs in stock")
        #expect(viewModel.addCaption(for: try product("Bonding agent")) == "0 unopened · 1 open")
        viewModel.searchText = "gau"
        #expect(viewModel.addableProducts.map(\.name) == ["Gauze"])
    }

    @Test func addingClosesTheSheetAndOffersUndo() async throws {
        let repository = FakeToBuyRepository()
        let added = AddedToBuy(id: UUID(), qty: 2, created: true)
        repository.addResult = .success(added)
        let viewModel = await make(repository)
        viewModel.segment = .ordered
        viewModel.openAddItem()
        let gauze = try product("Gauze")
        await viewModel.add(gauze)
        #expect(viewModel.sheet == nil)
        #expect(repository.adds == [gauze.id])
        #expect(viewModel.segment == .toBuy)
        #expect(viewModel.message == .init(
            title: "Added to To buy", detail: "Gauze · suggested 2 packs", undoItemID: added.id
        ))
        await viewModel.undoAdd(added.id)
        #expect(repository.removals == [added.id])
    }

    @Test func addingAProductAlreadyOnTheListOffersNoUndo() async throws {
        let repository = FakeToBuyRepository()
        repository.addResult = .success(AddedToBuy(id: try line("Endo file kit #15-40").id, qty: 4, created: false))
        let viewModel = await make(repository)
        let endo = try product("Endo file kit #15-40")
        await viewModel.add(endo)
        #expect(viewModel.message == .init(
            title: "Already on To buy", detail: "Endo file kit #15-40 · 4 kits", undoItemID: nil
        ))
    }

    @Test func productsThatFailToLoadAreExplainedInTheSheet() async {
        let repository = FakeToBuyRepository()
        repository.productsResult = .failure(AppError.network)
        let viewModel = await make(repository)
        viewModel.openAddItem()
        await viewModel.loadProducts()
        #expect(viewModel.addItemEmptyText == "Couldn't load products. Close and reopen Add item to try again.")
        #expect(viewModel.generalError == nil)
    }

    @Test func aFailedFirstLoadShowsTheErrorAndALaterOneKeepsTheList() async {
        let failing = FakeToBuyRepository()
        failing.itemsResult = .failure(AppError.network)
        let failed = await make(failing)
        #expect(failed.state == .failed(.network))

        let repository = FakeToBuyRepository()
        let viewModel = await make(repository)
        repository.itemsResult = .failure(AppError.network)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.toBuy.count == 3, "The list stays on screen")
        #expect(viewModel.generalError == nil, "No toast: reloads run on every tab change")
    }

    @Test func offlineTheLastListShowsFromTheCache() async {
        let cache = InMemoryResponseCache()
        _ = await make(cache: cache)
        let offline = FakeToBuyRepository()
        offline.itemsResult = .failure(AppError.network)
        let viewModel = ToBuyViewModel(
            repository: offline, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID, isAdmin: true
        )
        #expect(viewModel.toBuyCount == 3, "The cached list and its badge show at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.items.count == demo.count)
    }

    @Test func theCountsReadInTheSingularToo() {
        #expect(ToBuyViewModel.items(1) == "1 item")
        #expect(ToBuyViewModel.items(3) == "3 items")
    }
}
