import Foundation
import Observation

/// The Inventory list in browse mode (f16, f17, f19): every product of the clinic, searched by name and
/// narrowed by a status chip or a category, sorted by status priority then name. The last answer is
/// served from the cache while a fresh one loads or the network is gone (MS-108).
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

    private(set) var state: LoadState = .loading
    private(set) var products: [ProductSummary]
    var searchText = ""
    var filter: InventoryFilter
    /// A category name handed over by Inventory value (MS-135), shown as a removable chip.
    private(set) var category: String?

    private let repository: InventoryRepository
    private let cache: ResponseCaching
    private let formatters: ClinicFormatters
    private let clinicID: UUID

    init(
        repository: InventoryRepository,
        cache: ResponseCaching,
        formatters: ClinicFormatters,
        clinicID: UUID,
        filter: InventoryFilter = .all,
        category: String? = nil
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.filter = filter
        self.category = category
        products = cache.load([ProductSummary].self, for: Self.cacheKey(clinicID: clinicID)) ?? []
    }

    private static func cacheKey(clinicID: UUID) -> CacheKey {
        CacheKey(method: "InventoryRepository.products", clinicID: clinicID)
    }

    /// The rows in order: the chip and the category first, then the search (case and accent
    /// insensitive), sorted Out of stock › Low › Expiring › Missing expiry › Healthy, then by name.
    var visibleProducts: [ProductSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return products
            .filter { filter.includes($0.status) }
            .filter { category == nil || $0.categoryName == category }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
            .sorted { lhs, rhs in
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
        case .multiUse: "\(formatters.number(product.unopened)) unopened · \(product.openCount) open"
        }
        guard let category = product.categoryName, !category.isEmpty else { return figures }
        return "\(figures) · \(category)"
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
}
