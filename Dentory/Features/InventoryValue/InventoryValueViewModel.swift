import Foundation
import Observation

/// Inventory value (f10): the total at the last unit cost with what is expiring, used and received, the value by
/// category and the five most valuable products (PRD §5, MS-100 D7). The last answer is served from the cache while
/// a fresh one loads or the network is gone (MS-108).
@MainActor
@Observable
final class InventoryValueViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// One of the three figures under the total (f10).
    struct Stat: Equatable, Identifiable {
        let id: String
        /// The frame's short label; its space before "d" never breaks.
        let label: String
        /// What VoiceOver reads in place of the short label.
        let spokenLabel: String
        let value: String
        let tone: StatusTone?
    }

    static let emptyText = "Nothing in stock has a cost yet."
    static let footnote = "Value = quantity × last cost per unit from invoices. "
        + "Products without a cost are not included."
    static let noCategory = "No category"

    private(set) var state: LoadState = .loading
    private(set) var value: InventoryValue?

    private let repository: InventoryValueRepository
    private let cache: ResponseCaching
    private let formatters: ClinicFormatters
    private let clinicID: UUID

    init(repository: InventoryValueRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        value = cache.load(InventoryValue.self, for: Self.cacheKey(clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "InventoryValueRepository.value", clinicID: clinicID)
    }

    func load() async {
        do {
            let fresh = try await repository.value(clinicID: clinicID)
            value = fresh
            cache.store(fresh, for: Self.cacheKey(clinicID))
            state = .loaded
        } catch {
            // The last answer stays on screen; the banner says why it may be stale.
            state = value == nil ? .failed(AppError(error)) : .loaded
        }
    }

    /// "$12,420"
    var totalText: String {
        formatters.wholeMoney(value?.total ?? 0)
    }

    /// Expiring ≤ 90 d (warning while anything is at risk), Used, 30 d and Received, 30 d.
    var stats: [Stat] {
        guard let value else { return [] }
        return [
            Stat(
                id: "atRisk", label: "Expiring ≤ 90\u{00A0}d", spokenLabel: "Expiring within 90 days",
                value: formatters.wholeMoney(value.atRisk90), tone: value.atRisk90 > 0 ? .warning : nil
            ),
            Stat(
                id: "used", label: "Used, 30\u{00A0}d", spokenLabel: "Used in the last 30 days",
                value: formatters.wholeMoney(value.used30), tone: nil
            ),
            Stat(
                id: "received", label: "Received, 30\u{00A0}d", spokenLabel: "Received in the last 30 days",
                value: formatters.wholeMoney(value.received30), tone: nil
            )
        ]
    }

    /// "3 products have no cost yet." while products in stock have none, so the total leaves them out.
    var uncostedText: String? {
        guard let count = value?.uncostedCount, count > 0 else { return nil }
        return count == 1 ? "1 product has no cost yet." : "\(count) products have no cost yet."
    }

    var categories: [InventoryValueCategory] { value?.categories ?? [] }

    var topProducts: [InventoryValueProduct] { value?.topProducts ?? [] }

    /// An answer with nothing worth anything to list.
    var isEmpty: Bool { value != nil && categories.isEmpty && topProducts.isEmpty }

    /// "Anesthetic", or "No category" for the products without one.
    func name(of category: InventoryValueCategory) -> String {
        category.name ?? Self.noCategory
    }

    /// The name Inventory filters by; nil for the products without a category, which it cannot filter.
    func filter(for category: InventoryValueCategory) -> String? {
        category.name
    }

    /// "$4,860"
    func valueText(of category: InventoryValueCategory) -> String {
        formatters.wholeMoney(category.value)
    }

    /// The category's part of the total, from 0 to 1, for its bar.
    func share(of category: InventoryValueCategory) -> Double {
        guard let total = value?.total, total > 0 else { return 0 }
        let share = NSDecimalNumber(decimal: category.value / total).doubleValue
        return min(max(share, 0), 1)
    }

    /// "39%", or "<1%" for a category worth too little to round to 1%.
    func shareText(of category: InventoryValueCategory) -> String {
        let percent = Int((share(of: category) * 100).rounded())
        return percent == 0 && category.value > 0 ? "<1%" : "\(percent)%"
    }

    /// "54 × $1.80"
    func line(for product: InventoryValueProduct) -> String {
        "\(formatters.number(product.quantity)) × \(formatters.unitCost(product.unitCost))"
    }

    /// "$97"
    func valueText(of product: InventoryValueProduct) -> String {
        formatters.wholeMoney(product.value)
    }
}
