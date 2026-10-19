import Foundation

/// Product detail without a server: Septocaine as f20 draws it, and a plain detail for the other demo
/// products, with whatever the Edit sheet saved applied on top. Add to buy and its Undo, adjustments
/// and their Undo are remembered in memory, so the figures and the history move the way the server's
/// would; a count applied on Inventory (MS-121) shows as "Counted" and a Physical count row; Delete product
/// takes the product out of the shared store.
final class DemoProductDetailRepository: ProductDetailRepository, @unchecked Sendable {
    /// What an adjustment did, so Undo can reverse it.
    private struct Adjustment {
        let productID: UUID
        let delta: Decimal
        let reason: AdjustmentReason
    }

    private(set) var toBuyItemIDs: [UUID: UUID] = [:]
    private var quantityDeltas: [UUID: Decimal] = [:]
    private var extraHistory: [UUID: [StockTransaction]] = [:]
    private var adjustments: [UUID: Adjustment] = [:]
    private let byName: String
    private let lock = NSLock()
    private let store: DemoProductStore

    /// `byName` is who the history rows name: the signed-in person of the demo clinic.
    init(store: DemoProductStore, byName: String = "Sarah Mitchell") {
        self.store = store
        self.byName = byName
    }

    func detail(productID: UUID) async throws -> ProductDetail {
        try await Task.sleep(for: .milliseconds(200))
        guard let summary = store.summary(id: productID) else { throw AppError.notFound }
        let onToBuy = lock.withLock { toBuyItemIDs[productID] }
        let delta = lock.withLock { quantityDeltas[productID] ?? 0 }
        let history = lock.withLock { extraHistory[productID] ?? [] }
        let base: ProductDetail
        if summary.id == ProductSummary.demo[0].id {
            base = ProductDetail.demoSeptocaine(toBuyItemID: onToBuy)
        } else {
            base = ProductDetail(
                id: summary.id, name: summary.name, categoryName: summary.categoryName, unit: summary.unit,
                packUnit: nil, packSize: nil, minimum: summary.minimum, target: summary.minimum * 3,
                tracking: summary.tracking, location: summary.location, status: summary.status,
                quantity: summary.quantity, unopened: summary.unopened, openCount: summary.openCount,
                missingExpiryQuantity: 0, usedInLast30Days: 0, lastCountedAt: nil, toBuyItemID: onToBuy,
                batches: [],
                openBottles: summary.tracking == .multiUse ? ProductDetail.demoBottles(count: summary.openCount) : [],
                history: [],
                categoryID: store.categories.first { $0.name == summary.categoryName }?.id
            )
        }
        let edited = store.draft(for: productID).map {
            base.applying($0, categoryName: store.categoryName(for: $0.categoryID), status: summary.status)
        } ?? base
        let counts = store.countRecords(for: productID)
        // The other products are built from the store's row, which a count already moved; Septocaine's
        // drawn figures are not.
        let countDelta = summary.id == ProductSummary.demo[0].id ? counts.reduce(Decimal(0)) { $0 + $1.delta } : 0
        let countRows = counts.map { record in
            StockTransaction(
                id: UUID(), type: .count, delta: record.delta, quantityBefore: record.quantityBefore,
                quantityAfter: record.quantityAfter, reason: "Physical count", referenceLabel: "Physical count",
                at: record.at, byName: record.byName
            )
        }
        return edited
            .counted(at: counts.first?.at)
            .adjusted(by: delta + countDelta, history: history + countRows + edited.history)
    }

    func addToBuy(clinicID: UUID, productID: UUID, quantity: Decimal, userID: UUID) async throws -> UUID {
        try await Task.sleep(for: .milliseconds(200))
        let id = UUID()
        lock.withLock { toBuyItemIDs[productID] = id }
        return id
    }

    func removeFromToBuy(itemID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        lock.withLock { toBuyItemIDs = toBuyItemIDs.filter { $0.value != itemID } }
    }

    func archiveProduct(id: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        guard store.archive(id: id) else { throw AppError.notFound }
    }

    func adjust(
        productID: UUID, actualQuantity: Decimal, reason: AdjustmentReason, note: String?
    ) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(200))
        let current = try await detail(productID: productID)
        let delta = actualQuantity - current.unopened
        let actionID = UUID()
        lock.withLock {
            adjustments[actionID] = Adjustment(productID: productID, delta: delta, reason: reason)
            quantityDeltas[productID, default: 0] += delta
            extraHistory[productID, default: []].insert(
                StockTransaction(
                    id: UUID(), type: .adjustment, delta: delta, quantityBefore: current.quantity,
                    quantityAfter: current.quantity + delta, reason: reason.rawValue, referenceLabel: reason.rawValue,
                    at: Session.demoNow, byName: byName
                ),
                at: 0
            )
        }
        return .applied(actionID: actionID)
    }

    func undoAdjustment(actionID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        guard let adjustment = lock.withLock({ adjustments.removeValue(forKey: actionID) }) else {
            throw AppError.validation(field: nil, message: "already undone")
        }
        let current = try await detail(productID: adjustment.productID)
        lock.withLock {
            quantityDeltas[adjustment.productID, default: 0] -= adjustment.delta
            extraHistory[adjustment.productID, default: []].insert(
                StockTransaction(
                    id: UUID(), type: .adjustment, delta: -adjustment.delta, quantityBefore: current.quantity,
                    quantityAfter: current.quantity - adjustment.delta, reason: adjustment.reason.rawValue,
                    referenceLabel: "Undo · \(adjustment.reason.rawValue)", at: Session.demoNow, byName: byName
                ),
                at: 0
            )
        }
    }
}

private extension ProductDetail {
    /// The detail with the last count's date, when a count moved it.
    func counted(at date: Date?) -> ProductDetail {
        guard let date else { return self }
        return ProductDetail(
            id: id, name: name, categoryName: categoryName, unit: unit, packUnit: packUnit, packSize: packSize,
            minimum: minimum, target: target, tracking: tracking, location: location, status: status,
            quantity: quantity, unopened: unopened, openCount: openCount, missingExpiryQuantity: missingExpiryQuantity,
            usedInLast30Days: usedInLast30Days, lastCountedAt: date, toBuyItemID: toBuyItemID, batches: batches,
            openBottles: openBottles, history: history, categoryID: categoryID, supplier: supplier
        )
    }

    /// The detail with the sheet's fields on top; the stock figures and the ledger stay.
    func applying(_ draft: ProductDraft, categoryName: String?, status: ProductStatus) -> ProductDetail {
        ProductDetail(
            id: id, name: draft.name, categoryName: categoryName, unit: draft.unit, packUnit: draft.packUnit,
            packSize: draft.packSize, minimum: draft.minimum, target: draft.target, tracking: draft.tracking,
            location: draft.location, status: status, quantity: quantity, unopened: unopened,
            openCount: openCount, missingExpiryQuantity: missingExpiryQuantity,
            usedInLast30Days: usedInLast30Days, lastCountedAt: lastCountedAt, toBuyItemID: toBuyItemID,
            batches: batches, openBottles: openBottles, history: history,
            categoryID: draft.categoryID, supplier: draft.supplier
        )
    }
}

extension ProductDetail {
    /// Septocaine of f20: 54 cartridges in two dated batches, 38 used in 30 days, counted October 1.
    nonisolated static func demoSeptocaine(toBuyItemID: UUID? = nil) -> ProductDetail {
        let summary = ProductSummary.demo[0]
        let october1 = Date(timeIntervalSince1970: 1_790_882_040) // Oct 1, 2026 · 3:14 PM in New York
        let september30 = Date(timeIntervalSince1970: 1_790_791_500) // Sep 30 · 2:05 PM
        return ProductDetail(
            id: summary.id, name: summary.name, categoryName: "Anesthetic", unit: "cartridges",
            packUnit: "box", packSize: 50, minimum: 20, target: 60, tracking: .countable,
            location: "Operatory 1 · Drawer A", status: .healthy, quantity: 54, unopened: 54, openCount: 0,
            missingExpiryQuantity: 0, usedInLast30Days: 38, lastCountedAt: october1, toBuyItemID: toBuyItemID,
            batches: [
                ProductBatch(
                    id: demoID("b1"), expiryMonth: CalendarDay(year: 2026, month: 12, day: 1), lot: "A112", quantity: 20
                ),
                ProductBatch(
                    id: demoID("b2"), expiryMonth: CalendarDay(year: 2026, month: 12, day: 1), lot: "B441", quantity: 34
                )
            ],
            openBottles: [],
            history: [
                StockTransaction(
                    id: demoID("f1"), type: .count, delta: -2, quantityBefore: 43, quantityAfter: 41,
                    reason: "Physical count", referenceLabel: nil, at: october1, byName: "Michael Reyes"
                ),
                StockTransaction(
                    id: demoID("f2"), type: .procedure, delta: -2, quantityBefore: 45, quantityAfter: 43,
                    reason: nil, referenceLabel: "Root canal", at: october1.addingTimeInterval(-3_600),
                    byName: "Sarah Mitchell"
                ),
                StockTransaction(
                    id: demoID("f3"), type: .receiving, delta: 40, quantityBefore: 5, quantityAfter: 45,
                    reason: nil, referenceLabel: "Invoice INV-10092", at: september30, byName: "Michael Reyes"
                )
            ],
            categoryID: ProductCategory.demo[0].id, supplier: "Patterson"
        )
    }

    /// A fixed id for the demo rows: `demoID("b1")` is …0000b1.
    private nonisolated static func demoID(_ suffix: String) -> UUID {
        UUID(uuidString: "00000000-0000-4000-8000-0000000000\(suffix)") ?? UUID()
    }

    nonisolated static func demoBottles(count: Int) -> [OpenBottle] {
        (0..<count).map { index in
            OpenBottle(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-0000000000c%01d", index)) ?? UUID(),
                openedAt: Session.demoNow.addingTimeInterval(Double(-(index + 1)) * 86_400 * 3),
                openedByName: index == 0 ? "Sarah Mitchell" : "Michael Reyes"
            )
        }
    }

}
