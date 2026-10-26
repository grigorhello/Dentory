import Foundation
import Observation

/// Receive manually (f24; PRD §6.5; Appendix B `manual`, Appendix C `pickProduct`), Admin only: the product, chosen on
/// Choose product (which turns into New product), the quantity in the unit it is received in, the cost per received
/// unit, the lot and the expiry month; Receive converts packs to counted units and the cost to a cost per counted unit
/// and sends one line through `stock_receive`, which also moves the product's To buy line to Received. The products are
/// served from the cache while fresh ones load or the network is gone (MS-108), and a receipt made offline is queued.
/// The labels and lines are in `ManualReceiveViewModel+Copy.swift`.
@MainActor
@Observable
final class ManualReceiveViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// Choose product, the one sheet over the form; New swaps New product in for the list, Back swaps it out.
    enum Sheet: Identifiable, Equatable {
        case pickProduct
        var id: Self { self }
    }

    /// A toast the screen shows: the receipt (no Undo, PRD §7), or a product created on the sheet.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }

    private(set) var state: LoadState = .loading
    /// The clinic's active products, for Choose product and the chosen one's figures.
    private(set) var products: [ReceivableProduct]
    /// The chosen product: the route's `productId` until one is picked.
    private(set) var productID: UUID?
    var quantityText = ""
    var costText = ""
    var lot = ""
    var expiryMonth: CalendarDay?
    var sheet: Sheet?
    var searchText = ""
    /// New on Choose product: the sheet shows New product, with the back chevron to the list.
    private(set) var isCreatingProduct = false
    /// Set once the delivery is in: the screen shows it as a toast and opens Inventory.
    private(set) var received: Message?
    private(set) var message: Message?
    /// A refusal of the receipt; the screen shows it as a toast and keeps what was typed.
    private(set) var generalError: AppError?

    let formatters: ClinicFormatters
    private let repository: ManualReceiveRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let analytics: Analytics
    private let submitGuard = SubmitGuard()

    init(
        repository: ManualReceiveRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID,
        productID: UUID?, analytics: Analytics
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.productID = productID
        self.analytics = analytics
        products = Self.byName(cache.load([ReceivableProduct].self, for: Self.cacheKey(clinicID)) ?? [])
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ManualReceiveRepository.products", clinicID: clinicID)
    }

    /// The chosen product, once the products are in.
    var product: ReceivableProduct? {
        productID.flatMap { id in products.first { $0.id == id } }
    }

    var isReceiving: Bool { submitGuard.isBusy }

    /// Reads the products; a reload that fails keeps the last ones.
    func load() async {
        do {
            let fresh = try await repository.products(clinicID: clinicID)
            cache.store(fresh, for: Self.cacheKey(clinicID))
            products = Self.byName(fresh)
            state = .loaded
        } catch {
            state = products.isEmpty ? .failed(AppError(error)) : .loaded
        }
    }

    // MARK: - Choose product

    func openPicker() {
        searchText = ""
        isCreatingProduct = false
        sheet = .pickProduct
    }

    /// The products matching the search (case and accent insensitive), by name.
    var pickableProducts: [ReceivableProduct] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return products }
        return products.filter { $0.name.localizedStandardContains(query) }
    }

    func isChosen(_ product: ReceivableProduct) -> Bool {
        product.id == productID
    }

    func choose(_ product: ReceivableProduct) {
        productID = product.id
        sheet = nil
    }

    /// New: New product takes the list's place, its name starting as the search.
    func createProduct() {
        isCreatingProduct = true
    }

    /// New product's back chevron.
    func backToPicker() {
        isCreatingProduct = false
    }

    /// Create and select: the sheet closes at once (so the button cannot create a second product), the new product is
    /// chosen, and its figures show once the products come back with it.
    func productCreated(_ id: UUID) async {
        sheet = nil
        productID = id
        message = Message(title: "Product created", detail: nil)
        await load()
    }

    // MARK: - Expiry

    /// The expiry as the month field picks it; `expiryMonth` keeps it as it is stored, the month's first day.
    var expiry: YearMonth? {
        get { expiryMonth.map(YearMonth.init(day:)) }
        set { expiryMonth = newValue.map(CalendarDay.init(yearMonth:)) }
    }

    /// The month the wheels open on while none is chosen: this month in the clinic's time zone.
    var openingMonth: YearMonth { YearMonth(day: formatters.thisMonth) }

    /// Three years back to ten ahead, as Add expiry offers them, stretched to the chosen month's year.
    var years: ClosedRange<Int> { formatters.expiryYears(including: expiryMonth) }

    /// "Mar 2027".
    func monthTitle(_ month: YearMonth) -> String { formatters.shortMonth(CalendarDay(yearMonth: month)) }

    // MARK: - Receive

    /// The quantity typed, in the unit the product is received in.
    var quantity: Decimal? { QuantityText.parse(quantityText, locale: formatters.locale) }

    /// The cost per received unit typed; nil while the field is empty.
    var cost: Decimal? { QuantityText.parse(costText, locale: formatters.locale) }

    /// "Enter a number" once the field holds something that is not one.
    var quantityError: String? { Self.numberError(quantityText, value: quantity) }
    var costError: String? { Self.numberError(costText, value: cost) }

    /// Receive waits for a product and a quantity above 0 (f24), and for a cost that reads as a number when one is
    /// typed.
    var canReceive: Bool {
        guard !isReceiving, product != nil, let quantity, quantity > 0 else { return false }
        return costError == nil
    }

    /// Sends the delivery in counted units at the cost per counted unit, with the lot and expiry when given.
    func receive() async {
        guard canReceive, let product, let quantity else { return }
        let trimmedLot = lot.trimmingCharacters(in: .whitespacesAndNewlines)
        let receipt = ManualReceipt(
            clinicID: clinicID, productID: product.id, quantity: product.countedQuantity(received: quantity),
            unitCost: cost.map(product.unitCost(perReceived:)), lot: trimmedLot.isEmpty ? nil : trimmedLot,
            expiryMonth: expiryMonth
        )
        await submitGuard.run {
            generalError = nil
            do {
                _ = try await repository.receive(receipt)
                analytics.track(.manualReceived)
                received = receivedMessage(product: product, quantity: receipt.quantity)
            } catch {
                generalError = AppError(error)
            }
        }
    }

    func clearMessage() {
        message = nil
    }

    func clearGeneralError() {
        generalError = nil
    }

    /// Sorted once as they arrive, so the search only filters.
    private static func byName(_ products: [ReceivableProduct]) -> [ReceivableProduct] {
        products.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func numberError(_ text: String, value: Decimal?) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && value == nil ? "Enter a number" : nil
    }
}
