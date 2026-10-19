import Foundation
import Observation

/// Product detail (f20 Admin, f21 Staff): the figures, the expiry and bottle cards and the history of one
/// product, with Add to buy and its Undo (MS-116) and the Adjust sheet with its Undo (MS-118). The last
/// answer is served from the cache while a fresh one loads or the network is gone (MS-108). Edit, batches,
/// bottles and Delete arrive with their own tickets. The card rows are built in `ProductDetailViewModel+Rows.swift`.
@MainActor
@Observable
final class ProductDetailViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// The sheets this screen presents (Appendix C `newProduct` in edit mode, `deleteProduct`, `adjust`, `batch`).
    enum Sheet: Hashable, Identifiable {
        case edit
        case delete
        case adjust
        case addExpiry
        case editBatch(UUID)
        var id: Self { self }
    }

    /// What the toast says after Add to buy; the view offers Undo on it.
    struct AddedToBuy: Equatable {
        let itemID: UUID
        let title: String
        let detail: String
    }

    /// What the toast says after an adjustment; Undo is offered while `actionID` is known (MS-100 D10).
    struct Adjusted: Equatable {
        let actionID: UUID?
        let title: String
        let detail: String
    }

    private(set) var state: LoadState = .loading
    private(set) var detail: ProductDetail?
    private(set) var addedToBuy: AddedToBuy?
    private(set) var adjusted: Adjusted?
    /// The last applied adjustment, undoable until Undo runs or the next adjustment replaces it.
    private(set) var undoableAdjustmentID: UUID?
    var sheet: Sheet?
    /// Set once "Delete product" went through: the view leaves the screen with its toast.
    private(set) var isDeleted = false
    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?

    /// Read by the sheet factories in `ProductDetailViewModel+Sheets.swift`.
    let repository: ProductDetailRepository
    private let cache: ResponseCaching
    let formatters: ClinicFormatters
    private let clinicID: UUID
    private let userID: UUID
    private let productID: UUID
    private let submitGuard = SubmitGuard()

    init(
        repository: ProductDetailRepository,
        cache: ResponseCaching,
        formatters: ClinicFormatters,
        clinicID: UUID,
        userID: UUID,
        productID: UUID
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.userID = userID
        self.productID = productID
        detail = cache.load(ProductDetail.self, for: cacheKey)
    }

    private var cacheKey: CacheKey {
        CacheKey(method: "ProductDetailRepository.detail/\(productID.uuidString.lowercased())", clinicID: clinicID)
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    func load() async {
        do {
            let fresh = try await repository.detail(productID: productID)
            detail = fresh
            cache.store(fresh, for: cacheKey)
            state = .loaded
        } catch {
            let appError = AppError(error)
            state = detail == nil ? .failed(appError) : .loaded
        }
    }

    // MARK: - Header and quantity card

    /// "Anesthetic · 1 box = 50 cartridges", or "Anesthetic · cartridges" without a pack.
    var contextLine: String {
        guard let detail else { return "" }
        let pack: String = if let packUnit = detail.packUnit, let packSize = detail.packSize {
            "1 \(packUnit) = \(formatters.number(Decimal(packSize))) \(detail.unit)"
        } else {
            detail.unit
        }
        return [detail.categoryName, pack].compactMap { $0 }.joined(separator: " · ")
    }

    var availableText: String { detail.map { formatters.number($0.quantity) } ?? "" }
    var minimumText: String { detail.map { formatters.number($0.minimum) } ?? "" }
    var targetText: String { detail.map { formatters.number($0.target) } ?? "" }

    /// "System estimate · 38 cartridges used in 30 days"
    var estimateLine: String {
        guard let detail else { return "" }
        return "System estimate · \(formatters.quantity(detail.usedInLast30Days, unit: detail.unit)) used in 30 days"
    }

    /// "Counted Oct 1" or "Never counted"
    var countedLine: String {
        guard let detail else { return "" }
        return detail.lastCountedAt.map { "Counted \(formatters.monthDay($0))" } ?? "Never counted"
    }

    /// "Recommended: add 6 cartridges" when Low or Out of stock and the target is above the quantity.
    var recommendationLine: String? {
        guard let detail, detail.status == .low || detail.status == .outOfStock, detail.target > detail.quantity else {
            return nil
        }
        return "Recommended: add \(formatters.quantity(detail.target - detail.quantity, unit: detail.unit))"
    }

    // MARK: - Add to buy

    var isOnToBuy: Bool { detail?.toBuyItemID != nil }

    /// "Add to buy" for both roles (MS-100 G2 over the PRD's "Report low stock"); "On To buy" once it is on the list.
    var addToBuyTitle: String {
        isOnToBuy ? "On To buy" : "Add to buy"
    }

    /// Target minus quantity, at least 1.
    var suggestedToBuyQuantity: Decimal {
        guard let detail else { return 1 }
        return max(detail.target - detail.quantity, 1)
    }

    func addToBuy() async {
        guard let detail, !isOnToBuy else { return }
        await submitGuard.run {
            generalError = nil
            do {
                let quantity = suggestedToBuyQuantity
                let itemID = try await repository.addToBuy(
                    clinicID: clinicID, productID: productID, quantity: quantity, userID: userID
                )
                self.detail = detail.onToBuy(itemID)
                addedToBuy = AddedToBuy(
                    itemID: itemID,
                    title: "Added to To buy",
                    detail: "\(detail.name) · \(formatters.quantity(quantity, unit: detail.unit))"
                )
            } catch {
                generalError = AppError(error)
                // The list may have changed under this screen (someone else added the product): the fresh
                // answer turns the button into "On To buy" instead of leaving a refusal to retry.
                await load()
            }
        }
    }

    func undoAddToBuy() async {
        guard let detail, let itemID = detail.toBuyItemID else { return }
        addedToBuy = nil
        do {
            try await repository.removeFromToBuy(itemID: itemID)
            self.detail = detail.onToBuy(nil)
        } catch {
            generalError = AppError(error)
        }
    }

    func clearAddedToBuy() {
        addedToBuy = nil
    }

    // MARK: - Delete product (MS-117); the other sheet intents are in ProductDetailViewModel+Sheets.swift

    func deleteProduct() async {
        guard let detail else { return }
        await submitGuard.run {
            generalError = nil
            do {
                try await repository.archiveProduct(id: detail.id)
                sheet = nil
                isDeleted = true
            } catch {
                generalError = AppError(error)
            }
        }
    }

    // MARK: - Adjust

    /// Closes the sheet, moves the figures by the difference at once, queues the toast and loads the fresh
    /// detail (the server's status, batches and history).
    func adjustmentSaved(_ saved: AdjustInventoryViewModel.Saved) async {
        sheet = nil
        guard let detail else { return }
        self.detail = detail.adjusted(by: saved.after - saved.before, history: detail.history)
        undoableAdjustmentID = saved.actionID
        adjusted = Adjusted(
            actionID: saved.actionID,
            title: "Inventory adjusted",
            detail: "\(detail.name) · \(formatters.number(saved.before)) → \(formatters.number(saved.after))"
        )
        await load()
    }

    func undoAdjustment() async {
        guard let actionID = undoableAdjustmentID else { return }
        undoableAdjustmentID = nil
        adjusted = nil
        do {
            try await repository.undoAdjustment(actionID: actionID)
        } catch {
            generalError = AppError(error)
        }
        await load()
    }

    func clearAdjusted() {
        adjusted = nil
    }

    func clearGeneralError() {
        generalError = nil
    }
}

private extension ProductDetail {
    func onToBuy(_ itemID: UUID?) -> ProductDetail {
        ProductDetail(
            id: id, name: name, categoryName: categoryName, unit: unit, packUnit: packUnit, packSize: packSize,
            minimum: minimum, target: target, tracking: tracking, location: location, status: status,
            quantity: quantity, unopened: unopened, openCount: openCount, missingExpiryQuantity: missingExpiryQuantity,
            usedInLast30Days: usedInLast30Days, lastCountedAt: lastCountedAt, toBuyItemID: itemID,
            batches: batches, openBottles: openBottles, history: history, categoryID: categoryID, supplier: supplier
        )
    }
}
