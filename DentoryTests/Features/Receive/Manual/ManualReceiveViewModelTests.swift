import Foundation
import Testing
@testable import Dentory

/// Receive manually (f24, MS-127): Choose product and New, the labels in the unit a product is received in, the line
/// saying what the quantity does, when Receive is ready, and the receipt in counted units at the cost per counted unit.
struct ManualReceiveViewModelTests {
    private static let namesInOrder = [
        "Composite A2", "Endo file kit #15-40", "Gauze", "Root canal sealer", "Septocaine 4% 1:100,000"
    ]

    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        _ repository: FakeManualReceiveRepository = FakeManualReceiveRepository(), productID: UUID? = nil,
        cache: ResponseCaching = InMemoryResponseCache(), analytics: SpyAnalytics = SpyAnalytics(), loads: Bool = true
    ) async -> ManualReceiveViewModel {
        let viewModel = ManualReceiveViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            productID: productID, analytics: analytics
        )
        if loads {
            await viewModel.load()
        }
        return viewModel
    }

    /// The form with `product` chosen and `quantity` typed.
    private func form(
        _ product: ReceivableProduct, quantity: String = "", repository: FakeManualReceiveRepository = .init(),
        analytics: SpyAnalytics = SpyAnalytics()
    ) async -> ManualReceiveViewModel {
        let viewModel = await make(repository, analytics: analytics)
        viewModel.choose(product)
        viewModel.quantityText = quantity
        return viewModel
    }

    // MARK: - Before a product

    @Test func theFormStartsAsF24DrawsIt() async {
        let viewModel = await make(loads: false)
        #expect(viewModel.product == nil)
        #expect(viewModel.quantityLabel == "Quantity")
        #expect(viewModel.costLabel == "Cost per unit")
        #expect(viewModel.currencySymbol == "$")
        #expect(viewModel.effectLine == nil)
        #expect(!viewModel.canReceive, "Disabled until a product and a quantity above 0")
        viewModel.quantityText = "5"
        #expect(!viewModel.canReceive, "A quantity alone is not enough")
    }

    @Test func theProductsLoadAndStayForOffline() async {
        let repository = FakeManualReceiveRepository()
        let cache = InMemoryResponseCache()
        let viewModel = await make(repository, cache: cache)
        #expect(repository.productCalls == [Session.demo.clinicID])
        #expect(viewModel.state == .loaded)
        #expect(viewModel.products.map(\.name) == Self.namesInOrder, "Sorted by name as they arrive")

        repository.productsResult = .failure(AppError.network)
        let offline = await make(repository, cache: cache)
        #expect(offline.products.map(\.name) == Self.namesInOrder, "The last answer serves while offline")
        #expect(offline.state == .loaded)
    }

    @Test func chooseProductSaysWhyItsListIsEmpty() async {
        let repository = FakeManualReceiveRepository()
        repository.productsResult = .failure(AppError.network)
        let failed = await make(repository)
        #expect(failed.pickEmptyText == "Couldn't load products. Reopen Choose product to try again.")

        repository.productsResult = .success([])
        let empty = await make(repository)
        #expect(empty.pickEmptyText == "No products yet.")

        let viewModel = await make()
        viewModel.searchText = "Articaine"
        #expect(viewModel.pickableProducts.isEmpty)
        #expect(viewModel.pickEmptyText == "No products match.")
        #expect(await make(loads: false).pickEmptyText.isEmpty, "Nothing while they load")
    }

    @Test func theRouteProductIsChosenOnceTheProductsAreIn() async {
        let viewModel = await make(productID: ReceivableProduct.septocaine.id, loads: false)
        #expect(viewModel.product == nil)
        await viewModel.load()
        #expect(viewModel.product == .septocaine)
        #expect(viewModel.quantityLabel == "Quantity (boxes)")
    }

    // MARK: - Choose product

    @Test func chooseProductSearchesByNameAndChecksTheChosenOne() async {
        let viewModel = await make()
        viewModel.searchText = "left over"
        viewModel.openPicker()
        #expect(viewModel.sheet == .pickProduct)
        #expect(viewModel.searchText.isEmpty, "Each opening starts a new search")
        #expect(viewModel.pickableProducts.map(\.name) == Self.namesInOrder)
        viewModel.searchText = "SEPTO"
        #expect(viewModel.pickableProducts == [.septocaine], "Case insensitive")
        viewModel.searchText = "  endo "
        #expect(viewModel.pickableProducts == [.endoKit])

        viewModel.choose(.endoKit)
        #expect(viewModel.sheet == nil)
        #expect(viewModel.product == .endoKit)
        #expect(viewModel.isChosen(.endoKit))
        #expect(!viewModel.isChosen(.septocaine))
    }

    @Test func newOpensNewProductFromTheSearchAndBackReturnsToTheList() async {
        let repository = FakeManualReceiveRepository()
        let viewModel = await make(repository)
        viewModel.openPicker()
        viewModel.searchText = "Articaine"
        viewModel.createProduct()
        #expect(viewModel.isCreatingProduct)
        #expect(viewModel.sheet == .pickProduct, "The same sheet")
        viewModel.backToPicker()
        #expect(!viewModel.isCreatingProduct)
        #expect(viewModel.searchText == "Articaine", "Back keeps the search")

        viewModel.createProduct()
        let articaine = ReceivableProduct(
            id: UUID(), name: "Articaine", categoryName: nil, unit: "cartridges", packUnit: "box", packSize: 50,
            tracking: .countable, quantity: 0, unopened: 0, openCount: 0
        )
        repository.productsResult = .success(ReceivableProduct.samples + [articaine])
        await viewModel.productCreated(articaine.id)
        #expect(viewModel.sheet == nil)
        #expect(viewModel.product == articaine, "Create and select chooses it")
        #expect(viewModel.message == .init(title: "Product created", detail: nil))
        #expect(viewModel.effectLine == "1 box = 50 cartridges")

        viewModel.clearMessage()
        viewModel.openPicker()
        #expect(!viewModel.isCreatingProduct, "Choose product opens on its list again")
    }

    // MARK: - Labels and lines

    @Test func theLabelsFollowTheUnitAProductIsReceivedIn() async {
        let septocaine = await form(.septocaine)
        #expect(septocaine.quantityLabel == "Quantity (boxes)")
        #expect(septocaine.costLabel == "Cost per box")
        let kit = await form(.endoKit)
        #expect(kit.quantityLabel == "Quantity (kits)")
        #expect(kit.costLabel == "Cost per kit")
        let gauze = await form(.gauze)
        #expect(gauze.costLabel == "Cost per pack")
    }

    @Test func eachProductShowsItsCategoryAndStock() async {
        let viewModel = await make()
        #expect(viewModel.stockLine(for: .septocaine) == "Anesthetic\u{00A0}· 54 cartridges in stock")
        #expect(viewModel.stockLine(for: .endoKit) == "Endodontics\u{00A0}· 1 kit in stock")
        #expect(
            viewModel.stockLine(for: .sealer) == "Endodontics\u{00A0}· 0 unopened\u{00A0}· 1 open",
            "Multi-use: unopened and open"
        )
        #expect(viewModel.stockLine(for: .gauze) == "8 packs in stock", "No category")
    }

    /// PRD §6.5 and the ticket: "Current 1 → after 5 kits", "5 boxes = 250 cartridges · Current 54 → after 304".
    @Test func theLineUnderTheQuantitySaysWhatItDoes() async {
        let septocaine = await form(.septocaine)
        #expect(septocaine.effectLine == "1 box = 50 cartridges", "Before a quantity, the pack alone")
        septocaine.quantityText = "5"
        #expect(septocaine.effectLine == "5 boxes = 250 cartridges\u{00A0}· Current 54 → after 304")
        septocaine.quantityText = "1"
        #expect(septocaine.effectLine == "1 box = 50 cartridges\u{00A0}· Current 54 → after 104")

        let kit = await form(.endoKit)
        #expect(kit.effectLine == nil, "Received by the unit: nothing before a quantity")
        kit.quantityText = "4"
        #expect(kit.effectLine == "Current 1 → after 5 kits")
        kit.quantityText = "0"
        #expect(kit.effectLine == nil)
        kit.quantityText = "abc"
        #expect(kit.effectLine == nil)
    }

    /// For multi-use products the quantity is unopened units (the ticket): the line counts the unopened ones.
    @Test func aMultiUseProductCountsItsUnopenedOnes() async {
        let sealer = await form(.sealer, quantity: "4")
        #expect(sealer.effectLine == "Current 0 → after 4 unopened kits")
        sealer.quantityText = "1"
        #expect(sealer.effectLine == "Current 0 → after 1 unopened kit")
        let composite = await form(.composite, quantity: "2")
        #expect(composite.effectLine == "2 boxes = 20 syringes\u{00A0}· Current 2 → after 22 unopened")
    }

    // MARK: - Receive

    @Test func receiveWaitsForAProductAQuantityAboveZeroAndANumericCost() async {
        let viewModel = await form(.endoKit)
        #expect(!viewModel.canReceive)
        viewModel.quantityText = "0"
        #expect(!viewModel.canReceive)
        #expect(viewModel.quantityError == nil, "0 is a number: the button says it, not the field")
        viewModel.quantityText = "abc"
        #expect(!viewModel.canReceive)
        #expect(viewModel.quantityError == "Enter a number")
        viewModel.quantityText = "2"
        #expect(viewModel.canReceive)
        #expect(viewModel.quantityError == nil)
        viewModel.costText = "4,5x"
        #expect(viewModel.costError == "Enter a number")
        #expect(!viewModel.canReceive, "A cost that is not a number is not dropped silently")
        viewModel.costText = "45.00"
        #expect(viewModel.costError == nil)
        #expect(viewModel.canReceive)
    }

    /// The acceptance criterion: 5 boxes of a 50-pack add 250 with the lot and expiry, at the cost per cartridge.
    @Test func fiveBoxesOfAFiftyPackArriveAsTwoHundredFiftyCartridges() async throws {
        let repository = FakeManualReceiveRepository()
        let analytics = SpyAnalytics()
        let viewModel = await form(.septocaine, quantity: "5", repository: repository, analytics: analytics)
        viewModel.costText = "49.80"
        viewModel.lot = "  L-77 "
        viewModel.expiryMonth = CalendarDay(year: 2027, month: 3, day: 1)
        await viewModel.receive()

        #expect(repository.receipts == [ManualReceipt(
            clinicID: Session.demo.clinicID, productID: ReceivableProduct.septocaine.id, quantity: 250,
            unitCost: Decimal(996) / 1000, lot: "L-77",
            expiryMonth: CalendarDay(year: 2027, month: 3, day: 1)
        )])
        #expect(viewModel.received == .init(title: "Received", detail: "Septocaine 4% 1:100,000 +250 cartridges"))
        #expect(analytics.events == [.manualReceived])
        #expect(viewModel.generalError == nil)
    }

    @Test func withoutCostLotOrExpiryTheReceiptSendsNone() async {
        let repository = FakeManualReceiveRepository()
        let viewModel = await form(.endoKit, quantity: "1", repository: repository)
        viewModel.lot = "   "
        await viewModel.receive()
        #expect(repository.receipts == [ManualReceipt(
            clinicID: Session.demo.clinicID, productID: ReceivableProduct.endoKit.id, quantity: 1, unitCost: nil,
            lot: nil, expiryMonth: nil
        )])
        #expect(viewModel.received?.detail == "Endo file kit #15-40 +1 kit")
    }

    @Test func aReceiptQueuedOfflineStillLandsOnInventory() async {
        let repository = FakeManualReceiveRepository()
        repository.receiveResult = .success(.queued)
        let analytics = SpyAnalytics()
        let viewModel = await form(.sealer, quantity: "4", repository: repository, analytics: analytics)
        await viewModel.receive()
        #expect(repository.receipts.map(\.quantity) == [4])
        #expect(viewModel.received == .init(title: "Received", detail: "Root canal sealer +4 kits"))
        #expect(analytics.events == [.manualReceived])
    }

    @Test func aRefusedReceiptKeepsWhatWasTyped() async {
        let repository = FakeManualReceiveRepository()
        repository.receiveResult = .failure(AppError.validation(field: nil, message: "the product is archived"))
        let analytics = SpyAnalytics()
        let viewModel = await form(.endoKit, quantity: "3", repository: repository, analytics: analytics)
        viewModel.lot = "K-9"
        await viewModel.receive()
        #expect(viewModel.generalError == .validation(field: nil, message: "the product is archived"))
        #expect(viewModel.received == nil)
        #expect(analytics.events.isEmpty)
        #expect(viewModel.quantityText == "3" && viewModel.lot == "K-9" && viewModel.product == .endoKit)
        #expect(viewModel.canReceive, "Receive is offered again")
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }

    @Test func nothingIsSentBeforeTheFormIsReady() async {
        let repository = FakeManualReceiveRepository()
        let viewModel = await make(repository)
        viewModel.quantityText = "5"
        await viewModel.receive()
        #expect(repository.receipts.isEmpty)
        #expect(viewModel.received == nil)
    }

    // MARK: - Expiry

    @Test func theExpiryWheelsOpenOnThisMonthAndPickAMonthsFirstDay() async {
        let viewModel = await make(loads: false)
        #expect(viewModel.openingMonth == YearMonth(year: 2026, month: 10))
        #expect(viewModel.years == 2023...2036)
        viewModel.expiry = YearMonth(year: 2040, month: 1)
        #expect(viewModel.expiryMonth == CalendarDay(year: 2040, month: 1, day: 1), "Stored as the month's first day")
        #expect(viewModel.years == 2023...2040)
        #expect(viewModel.monthTitle(YearMonth(year: 2027, month: 3)) == "Mar 2027")
        viewModel.expiry = nil
        #expect(viewModel.expiryMonth == nil, "× clears it")
    }
}
