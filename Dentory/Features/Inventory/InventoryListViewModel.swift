import Foundation
import Observation

/// The Inventory list (f16, f17, f19): every product of the clinic, searched by name and narrowed by a
/// status chip or a category, sorted by status priority then name. The last answer is served from the cache
/// while a fresh one loads or the network is gone (MS-108). The same list counts stock (f18, MS-121): `count`
/// holds the counts while counting, kept as a draft on the device; its rows, labels and sheets are in
/// `InventoryListViewModel+Count.swift`.
@MainActor
@Observable
final class InventoryListViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }
    enum EmptyReason: Equatable {
        /// The clinic has no products at all.
        case noProducts
        /// Products exist, but none passes the search, the chip and the category.
        case noMatches
    }

    /// The sheets of count mode (Appendix C `reviewCount`, `cancelCount`).
    enum CountSheet: Identifiable, Equatable {
        case review
        case discard
        var id: Self { self }
    }

    /// What the toast says once a count is applied (no Undo, PRD §7).
    struct CountApplied: Equatable {
        let title: String
        let detail: String
    }

    private(set) var state: LoadState = .loading
    private(set) var products: [ProductSummary]
    var searchText = ""
    var filter: InventoryFilter
    /// A category name handed over by Inventory value (MS-135), shown as a removable chip.
    private(set) var category: String?
    /// The count in progress; nil in browse mode.
    private(set) var count: StockCount?
    var countSheet: CountSheet?
    private(set) var countApplied: CountApplied?
    /// A refusal of Apply count; the review sheet shows it above its buttons.
    private(set) var countError: AppError?

    private let repository: InventoryRepository
    private let cache: ResponseCaching
    private let draftStore: CountDraftStoring
    let formatters: ClinicFormatters
    private let clinicID: UUID
    private let userID: UUID
    private let analytics: Analytics
    private let submitGuard = SubmitGuard()

    /// A draft left by the same person in the same clinic reopens count mode with its counts.
    init(
        repository: InventoryRepository,
        cache: ResponseCaching,
        draftStore: CountDraftStoring,
        formatters: ClinicFormatters,
        clinicID: UUID,
        userID: UUID,
        analytics: Analytics,
        filter: InventoryFilter = .all,
        category: String? = nil
    ) {
        self.repository = repository
        self.cache = cache
        self.draftStore = draftStore
        self.formatters = formatters
        self.clinicID = clinicID
        self.userID = userID
        self.analytics = analytics
        self.filter = filter
        self.category = category
        products = cache.load([ProductSummary].self, for: Self.cacheKey(clinicID: clinicID)) ?? []
        if let draft = draftStore.load(), draft.clinicID == clinicID, draft.userID == userID {
            count = draft
        }
    }

    private static func cacheKey(clinicID: UUID) -> CacheKey {
        CacheKey(method: "InventoryRepository.products", clinicID: clinicID)
    }

    /// The rows in order: the chip and the category first, then the search (case and accent
    /// insensitive), sorted Out of stock › Low › Expiring › Missing expiry › Healthy, then by name.
    var visibleProducts: [ProductSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sortedProducts(
            products
                .filter { filter.includes($0.status) }
                .filter { category == nil || $0.categoryName == category }
                .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
        )
    }

    private func sortedProducts(_ products: [ProductSummary]) -> [ProductSummary] {
        products.sorted { lhs, rhs in
            if lhs.status.sortRank != rhs.status.sortRank { return lhs.status.sortRank < rhs.status.sortRank }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Why the list is empty, once there is an answer to show; nil while the first load is on its way.
    var emptyReason: EmptyReason? {
        guard visibleProducts.isEmpty else { return nil }
        if products.isEmpty {
            return state == .loaded ? .noProducts : nil
        }
        return .noMatches
    }

    /// "54 cartridges · Anesthetic", or "1 unopened · 2 open · Sterilization" for a multi-use product.
    func caption(for product: ProductSummary) -> String {
        let figures = switch product.tracking {
        case .countable: formatters.quantity(product.quantity, unit: product.unit)
        case .multiUse: "\(formatters.number(product.unopened)) unopened\(Caption.separator)\(product.openCount) open"
        }
        return Caption.joined(figures, product.categoryName)
    }

    func load() async {
        do {
            let fresh = try await repository.products(clinicID: clinicID)
            products = fresh
            cache.store(fresh, for: Self.cacheKey(clinicID: clinicID))
            state = .loaded
        } catch {
            let appError = AppError(error)
            // The last answer stays on screen; the banner says why it may be stale.
            state = products.isEmpty ? .failed(appError) : .loaded
        }
    }

    /// Home's tiles preselect a chip (`home.tile.missingExpiry`).
    func apply(filter: InventoryFilter) {
        self.filter = filter
    }

    /// Inventory value hands over a category (MS-135).
    func apply(category: String?) {
        self.category = category
    }

    func clearCategory() {
        category = nil
    }

    // MARK: - Count stock (MS-121)

    var isCounting: Bool { count != nil }

    /// The corrected products of the whole list, whatever the search and the chip show, in list order.
    var corrections: [ProductSummary] {
        guard let count else { return [] }
        return count.corrections(among: sortedProducts(products))
    }

    /// How many products the count corrects, without ordering them (the labels and the buttons' state).
    var correctionCount: Int {
        guard let count else { return 0 }
        return products.count(where: count.isCorrection)
    }

    var isApplyingCount: Bool { submitGuard.isBusy }

    func startCount() {
        count = StockCount(clinicID: clinicID, userID: userID, startedAt: formatters.clock.now)
    }

    func setCount(_ value: Int, for product: ProductSummary) {
        count?.set(value, for: product)
        saveDraft()
    }

    /// Undo on a review row: the product goes back to its estimate.
    func undoCorrection(_ product: ProductSummary) {
        count?.reset(product.id)
        saveDraft()
    }

    func reviewCount() {
        guard correctionCount > 0 else { return }
        countError = nil
        countSheet = .review
    }

    /// Cancel in the header: with corrections pending it asks first, else count mode ends silently.
    func cancelCount() {
        if correctionCount == 0 {
            endCount()
        } else {
            countSheet = .discard
        }
    }

    func discardCount() {
        countSheet = nil
        endCount()
    }

    /// Keep counting and Back to counting.
    func closeCountSheet() {
        countSheet = nil
    }

    /// Writes one Count transaction per corrected product, leaves count mode with the toast, shows the
    /// counted figures at once and loads the fresh list (the server's status). The cached list follows, so a count
    /// queued offline shows its figures on the next visit too, and analytics hears how many corrections went in.
    func applyCount() async {
        guard let count else { return }
        let corrected = corrections
        guard !corrected.isEmpty else { return }
        await submitGuard.run {
            countError = nil
            do {
                _ = try await repository.applyCount(
                    clinicID: clinicID,
                    counts: corrected.map { CountedQuantity(productID: $0.id, counted: Decimal(count.value(for: $0))) }
                )
                let counted = Dictionary(uniqueKeysWithValues: corrected.map { ($0.id, count.value(for: $0)) })
                products = products.map { product in
                    counted[product.id].map { product.counted(Decimal($0)) } ?? product
                }
                cache.store(products, for: Self.cacheKey(clinicID: clinicID))
                let seconds = count.seconds(until: formatters.clock.now)
                analytics.track(.countApplied(corrections: corrected.count, seconds: seconds))
                countApplied = CountApplied(title: "Count applied", detail: Self.productsUpdated(corrected.count))
                countSheet = nil
                endCount()
                await load()
            } catch {
                countError = AppError(error)
            }
        }
    }

    func clearCountApplied() {
        countApplied = nil
    }

    private func endCount() {
        count = nil
        draftStore.clear()
    }

    private func saveDraft() {
        guard let count else { return }
        draftStore.save(count)
    }
}
