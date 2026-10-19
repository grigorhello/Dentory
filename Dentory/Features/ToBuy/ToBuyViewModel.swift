import Foundation
import Observation

/// To buy (f25 Admin, f26 Staff): the segments To buy, Ordered and Received; quantities both roles change; the
/// admin's selection and Mark N as ordered; the swipe that removes a line; Add item. A quantity is saved a moment
/// after the last tap, so a run of taps is one write. The last list is served from the cache while a fresh one loads
/// or the network is gone (MS-108). The copy is in `ToBuyViewModel+Copy.swift`.
@MainActor
@Observable
final class ToBuyViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    nonisolated enum Segment: Hashable, Sendable {
        case toBuy, ordered, received
    }

    enum Sheet: Identifiable, Equatable {
        case addItem
        var id: Self { self }
    }

    /// A toast the screen shows; Undo takes an added line off again.
    struct Message: Equatable {
        let title: String
        let detail: String?
        let undoItemID: UUID?
    }

    private(set) var state: LoadState = .loading
    private(set) var items: [ToBuyItem] = []
    var segment: Segment = .toBuy
    /// Every line starts selected; this holds the ones the admin unticked.
    private(set) var deselected: Set<UUID> = []
    /// The clinic's products for Add item, loaded when the sheet opens.
    private(set) var products: [ProductSummary] = []
    private(set) var hasLoadedProducts = false
    /// The products did not load: Add item says so in place of its list.
    private(set) var productsFailed = false
    var searchText = ""
    var sheet: Sheet?
    private(set) var message: Message?
    private(set) var generalError: AppError?

    let isAdmin: Bool
    let formatters: ClinicFormatters
    private let repository: ToBuyRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let saveDelay: Duration
    private let markGuard = SubmitGuard()
    /// Quantities typed but not saved yet; a reload keeps them over the server's older figure.
    private var pendingQuantities: [UUID: Decimal] = [:]
    private var pendingSaves: [UUID: Task<Void, Never>] = [:]

    init(
        repository: ToBuyRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID,
        isAdmin: Bool, saveDelay: Duration = .milliseconds(600)
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.isAdmin = isAdmin
        self.saveDelay = saveDelay
        items = cache.load([ToBuyItem].self, for: Self.cacheKey(clinicID)) ?? []
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ToBuyRepository.items", clinicID: clinicID)
    }

    var toBuy: [ToBuyItem] { items.filter { $0.status == .toBuy } }
    var ordered: [ToBuyItem] { items.filter { $0.status == .ordered } }
    var received: [ToBuyItem] { items.filter { $0.status == .received } }

    /// The tab's badge: lines still to buy.
    var toBuyCount: Int { toBuy.count }

    var isMarking: Bool { markGuard.isBusy }

    /// Reads the list. A reload that fails keeps the last list on screen without a word: it runs on every tab
    /// change, and the offline banner already says why the list may be stale.
    func load() async {
        do {
            var fresh = try await repository.items(clinicID: clinicID)
            cache.store(fresh, for: Self.cacheKey(clinicID))
            for index in fresh.indices {
                if let pending = pendingQuantities[fresh[index].id] { fresh[index].buyQuantity = pending }
            }
            items = fresh
            state = .loaded
        } catch {
            state = items.isEmpty ? .failed(AppError(error)) : .loaded
        }
    }

    // MARK: - Quantities

    /// The stepper's binding: `$viewModel[quantityOf: id]`, never below 1; saved a moment after the last tap.
    subscript(quantityOf id: UUID) -> Int {
        get { items.first { $0.id == id }.map { Self.wholeNumber($0.buyQuantity) } ?? 1 }
        set {
            guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .toBuy else { return }
            let quantity = Decimal(max(newValue, 1))
            guard items[index].buyQuantity != quantity else { return }
            items[index].buyQuantity = quantity
            pendingQuantities[id] = quantity
            pendingSaves[id]?.cancel()
            pendingSaves[id] = Task { [weak self, saveDelay] in
                try? await Task.sleep(for: saveDelay)
                guard !Task.isCancelled else { return }
                await self?.saveQuantity(of: id)
            }
        }
    }

    /// Waits for every quantity still to be saved (before Mark as ordered, and in tests).
    func flushPendingSaves() async {
        for (id, task) in pendingSaves {
            task.cancel()
            pendingSaves[id] = nil
            await saveQuantity(of: id)
        }
    }

    private func saveQuantity(of id: UUID) async {
        pendingSaves[id] = nil
        guard let quantity = pendingQuantities[id] else { return }
        do {
            try await repository.setQuantity(itemID: id, quantity: quantity)
            if pendingQuantities[id] == quantity { pendingQuantities[id] = nil }
        } catch {
            pendingQuantities[id] = nil
            generalError = AppError(error)
            await load()
        }
    }

    // MARK: - Selection (Admin)

    /// The checkbox's binding: `$viewModel[isSelected: id]`.
    subscript(isSelected id: UUID) -> Bool {
        get { !deselected.contains(id) }
        set {
            if newValue { deselected.remove(id) } else { deselected.insert(id) }
        }
    }

    var selectedItems: [ToBuyItem] { toBuy.filter { !deselected.contains($0.id) } }

    /// "Clear" unticks every line; with none ticked it reads "Select all" and ticks them all again.
    func toggleAll() {
        let ids = toBuy.map(\.id)
        if selectedItems.isEmpty { deselected.subtract(ids) } else { deselected.formUnion(ids) }
    }

    var canMarkOrdered: Bool { isAdmin && !selectedItems.isEmpty && !isMarking }

    /// Saves any quantity still pending, then moves the selected lines to Ordered with today's date.
    func markOrdered() async {
        let ids = selectedItems.map(\.id)
        guard isAdmin, !ids.isEmpty else { return }
        await markGuard.run {
            await flushPendingSaves()
            do {
                let count = try await repository.markOrdered(clinicID: clinicID, itemIDs: ids)
                message = Message(title: "Marked as ordered", detail: Self.items(count), undoItemID: nil)
                deselected.subtract(ids)
                await load()
            } catch {
                generalError = AppError(error)
            }
        }
    }

    // MARK: - Remove

    /// The swipe's Remove: the line leaves at once; a refusal puts it back with a toast.
    func remove(_ id: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .toBuy else { return }
        pendingSaves[id]?.cancel()
        pendingSaves[id] = nil
        pendingQuantities[id] = nil
        let line = items.remove(at: index)
        do {
            try await repository.remove(itemID: id)
        } catch {
            items.insert(line, at: min(index, items.count))
            generalError = AppError(error)
        }
    }

    // MARK: - Add item

    func openAddItem() {
        searchText = ""
        sheet = .addItem
    }

    func loadProducts() async {
        do {
            products = try await repository.products(clinicID: clinicID)
            hasLoadedProducts = true
            productsFailed = false
        } catch {
            productsFailed = true
        }
    }

    /// The products not on the list yet, matching the search, by name.
    var addableProducts: [ProductSummary] {
        let listed = Set(toBuy.map(\.productID))
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return products
            .filter { !listed.contains($0.id) }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Closes the sheet and adds the product with its suggested quantity. The toast offers Undo only for a line this
    /// add created: a product already on the list (from another device, say) keeps its line.
    func add(_ product: ProductSummary) async {
        sheet = nil
        do {
            let added = try await repository.add(clinicID: clinicID, productID: product.id)
            segment = .toBuy
            message = addedMessage(added, product: product)
            await load()
        } catch {
            generalError = AppError(error)
        }
    }

    /// Undo of Add item: the line comes off again.
    func undoAdd(_ itemID: UUID) async {
        do {
            try await repository.remove(itemID: itemID)
        } catch {
            generalError = AppError(error)
        }
        await load()
    }

    func clearMessage() {
        message = nil
    }

    func clearGeneralError() {
        generalError = nil
    }

    private static func wholeNumber(_ value: Decimal) -> Int {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
