import Foundation
import Observation

/// Activity's History (PRD §6.8, f9), for Admin and Staff: every stock change newest first under its day, narrowed by a
/// chip, 50 at a time; or one product's changes, from Product detail's Show all. A chip's last page shows from the
/// cache while a fresh one loads or the network is gone (MS-108). Read-only: no Undo here (MS-100 D5).
@MainActor
@Observable
final class ActivityHistoryViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A day's entries under its eyebrow: "Today", "Yesterday", "Sep 30".
    struct Day: Identifiable, Equatable {
        /// The day's start in the clinic's time zone.
        let id: Date
        let title: String
        let entries: [ActivityHistoryEntry]
    }

    static let pageSize = 50

    /// The chip, bound to the row; `load()` follows it.
    var filter: ActivityHistoryFilter = .all
    private(set) var state: LoadState = .loading
    private(set) var entries: [ActivityHistoryEntry]
    /// True while the last page came back full, so another may follow.
    private(set) var hasMore = false
    /// One product's history, from Product detail; nil for the clinic's.
    let productID: UUID?
    /// An admin's History on Activity: a receipt opens the invoice it came from (MS-131).
    let opensInvoices: Bool
    let formatters: ClinicFormatters

    private let repository: ActivityRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    /// The chip whose entries are listed, so a new choice clears the old one's at once.
    private var listedFilter: ActivityHistoryFilter = .all
    private var isLoadingMore = false

    init(
        repository: ActivityRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID,
        productID: UUID? = nil, opensInvoices: Bool = false
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.productID = productID
        self.opensInvoices = opensInvoices
        entries = cache.load(
            [ActivityHistoryEntry].self, for: Self.cacheKey(.all, productID: productID, clinicID: clinicID)
        ) ?? []
    }

    /// One answer per chip, and per product for a product's history.
    private static func cacheKey(_ filter: ActivityHistoryFilter, productID: UUID?, clinicID: UUID) -> CacheKey {
        let product = productID.map { ".\($0.uuidString.lowercased())" } ?? ""
        return CacheKey(method: "ActivityRepository.history.\(filter.rawValue)\(product)", clinicID: clinicID)
    }

    private func cacheKey(_ filter: ActivityHistoryFilter) -> CacheKey {
        Self.cacheKey(filter, productID: productID, clinicID: clinicID)
    }

    /// The first page for the chip now chosen: what is cached for it shows at once, then the fresh page. A chip chosen
    /// meanwhile wins over a late answer.
    func load() async {
        let requested = filter
        if listedFilter != requested {
            listedFilter = requested
            entries = cache.load([ActivityHistoryEntry].self, for: cacheKey(requested)) ?? []
            hasMore = false
            state = .loading
        }
        do {
            let page = try await repository.history(
                clinicID: clinicID, filter: requested, productID: productID, after: nil, limit: Self.pageSize
            )
            guard requested == filter else { return }
            entries = page
            hasMore = page.count == Self.pageSize
            cache.store(page, for: cacheKey(requested))
            state = .loaded
        } catch {
            // A load cancelled by leaving the segment is no failure: the next appearance loads again.
            guard requested == filter, !Task.isCancelled else { return }
            // The last answer stays on screen; the banner says why it may be stale.
            state = entries.isEmpty ? .failed(AppError(error)) : .loaded
        }
    }

    /// The next page, when the last row shows. A failure keeps what is listed; the next appearance tries again.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = entries.last else { return }
        let requested = filter
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await repository.history(
                clinicID: clinicID, filter: requested, productID: productID, after: last, limit: Self.pageSize
            )
            guard requested == filter else { return }
            let listed = Set(entries.map(\.id))
            entries += page.filter { !listed.contains($0.id) }
            hasMore = page.count == Self.pageSize
        } catch {
            // What is listed stays; the next appearance of the last row tries again.
        }
    }

    /// The entries by day in the clinic's time zone, newest first.
    var days: [Day] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatters.timeZone
        var groups: [(start: Date, entries: [ActivityHistoryEntry])] = []
        for entry in entries {
            let start = calendar.startOfDay(for: entry.at)
            if groups.last?.start == start {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((start, [entry]))
            }
        }
        return groups.map { Day(id: $0.start, title: dayTitle(for: $0.start), entries: $0.entries) }
    }

    /// Nothing to list once there is an answer to show.
    var isEmpty: Bool { entries.isEmpty && state == .loaded }

    /// The invoice a row opens: a receipt's, on an admin's History. Invoices are an admin's (PRD §2), so Staff's rows
    /// open nothing and show no chevron.
    func invoiceID(for entry: ActivityHistoryEntry) -> UUID? {
        opensInvoices ? entry.invoiceID : nil
    }
}
