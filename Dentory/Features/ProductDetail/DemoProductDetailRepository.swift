import Foundation

/// Product detail without a server: Septocaine as f20 draws it, and a plain detail for the other demo
/// products, with whatever the Edit sheet saved applied on top. Add to buy and its Undo, adjustments
/// and their Undo, bottles opened and finished are remembered in memory, so the figures and the history
/// move the way the server's would; a count applied on Inventory (MS-121) shows as "Counted" and a Physical
/// count row; Delete product takes the product out of the shared store. Add expiry and Edit batch keep the
/// product's batches here, dating undated stock first like `batch_upsert` (MS-119).
final class DemoProductDetailRepository: ProductDetailRepository, @unchecked Sendable {
    /// What an adjustment did, so Undo can reverse it.
    private struct Adjustment {
        let productID: UUID
        let delta: Decimal
        let reason: AdjustmentReason
    }

    private(set) var toBuyItemIDs: [UUID: UUID] = [:]
    private var quantityDeltas: [UUID: Decimal] = [:]
    private var unopenedDeltas: [UUID: Decimal] = [:]
    private var finishedCounts: [UUID: Decimal] = [:]
    private var openedBottles: [UUID: [OpenBottle]] = [:]
    private var finishedBottleIDs: Set<UUID> = []
    private var extraHistory: [UUID: [StockTransaction]] = [:]
    private var adjustments: [UUID: Adjustment] = [:]
    private var batchEdits: [UUID: [ProductBatch]] = [:]
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
        let unopenedDelta = lock.withLock { unopenedDeltas[productID] ?? 0 }
        let finishedCount = lock.withLock { finishedCounts[productID] ?? 0 }
        let opened = lock.withLock { openedBottles[productID] ?? [] }
        let finished = lock.withLock { finishedBottleIDs }
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
                missingExpiryQuantity: summary.status == .missingExpiry ? summary.unopened : 0,
                usedInLast30Days: 0, lastCountedAt: nil, toBuyItemID: onToBuy,
                // A Missing expiry product holds its stock undated, so Add expiry has something to date.
                batches: summary.status == .missingExpiry ? [Self.undatedBatch(of: summary)] : [],
                openBottles: summary.tracking == .multiUse
                    ? ProductDetail.demoBottles(count: summary.openCount, of: summary.id)
                    : [],
                history: [],
                categoryID: store.categories.first { $0.name == summary.categoryName }?.id
            )
        }
        let edited = store.draft(for: productID).map {
            base.applying($0, categoryName: store.categoryName(for: $0.categoryID), status: summary.status)
        } ?? base
        let dated = lock.withLock { batchEdits[productID] }.map { edited.with(batches: $0) } ?? edited
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
        let bottles = (opened + dated.openBottles).filter { !finished.contains($0.id) }
        return dated
            .counted(at: counts.first?.at)
            .adjusted(by: delta + countDelta, history: history + countRows + dated.history)
            .replacingBottles(bottles, unopenedDelta: unopenedDelta, quantityDelta: -finishedCount)
    }

    func upsertBatch(
        productID: UUID, batchID: UUID?, expiryMonth: CalendarDay, quantity: Decimal, lot: String?
    ) async throws -> WriteOutcome {
        let current = try await detail(productID: productID)
        var batches = current.batches
        let change: Decimal
        if let batchID {
            guard let index = batches.firstIndex(where: { $0.id == batchID }) else {
                throw AppError.validation(field: nil, message: "unknown batch")
            }
            change = quantity - batches[index].quantity
            batches[index] = ProductBatch(id: batchID, expiryMonth: expiryMonth, lot: lot, quantity: quantity)
        } else {
            let undatedIndex = batches.firstIndex { $0.expiryMonth == nil }
            let moved = min(quantity, max(undatedIndex.map { batches[$0].quantity } ?? 0, 0))
            if let undatedIndex {
                let undated = batches[undatedIndex]
                batches[undatedIndex] = ProductBatch(
                    id: undated.id, expiryMonth: nil, lot: undated.lot, quantity: undated.quantity - moved
                )
            }
            batches.append(ProductBatch(id: UUID(), expiryMonth: expiryMonth, lot: lot, quantity: quantity))
            change = quantity - moved
        }
        lock.withLock {
            batchEdits[productID] = batches.filter { $0.quantity != 0 }
            guard change != 0 else { return }
            quantityDeltas[productID, default: 0] += change
            extraHistory[productID, default: []].insert(
                StockTransaction(
                    id: UUID(), type: .adjustment, delta: change, quantityBefore: current.quantity,
                    quantityAfter: current.quantity + change, reason: "Data correction",
                    referenceLabel: batchID == nil ? "Add expiry" : "Edit batch", at: Session.demoNow, byName: byName
                ),
                at: 0
            )
        }
        // Dating the last undated stock clears Missing expiry, on this screen and in the list.
        if current.status == .missingExpiry, !batches.contains(where: { $0.expiryMonth == nil && $0.quantity > 0 }) {
            store.setStatus(.healthy, for: productID)
        }
        return .applied(actionID: nil)
    }

    private static func undatedBatch(of summary: ProductSummary) -> ProductBatch {
        // Stable per product (d1…dc → e1…ec), so Edit batch can find it again.
        ProductBatch(
            id: ProductDetail.demoID("e" + summary.id.uuidString.suffix(1)), expiryMonth: nil, lot: nil,
            quantity: summary.unopened
        )
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

    func openBottle(productID: UUID) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(200))
        let current = try await detail(productID: productID)
        guard current.unopened > 0 else { throw AppError.validation(field: nil, message: "Out of stock") }
        lock.withLock {
            unopenedDeltas[productID, default: 0] -= 1
            openedBottles[productID, default: []].insert(
                OpenBottle(id: UUID(), openedAt: Session.demoNow, openedByName: byName), at: 0
            )
            extraHistory[productID, default: []].insert(
                StockTransaction(
                    id: UUID(), type: .adjustment, delta: 0, quantityBefore: current.quantity,
                    quantityAfter: current.quantity, reason: nil, referenceLabel: "Opened a new bottle",
                    at: Session.demoNow, byName: byName
                ),
                at: 0
            )
        }
        return .applied(actionID: UUID())
    }

    func finishBottle(openItemID: UUID) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(200))
        guard let productID = store.products.map(\.id).first(where: { id in
            bottleIDs(of: id).contains(openItemID)
        }) else { throw AppError.validation(field: nil, message: "unknown open item") }
        let current = try await detail(productID: productID)
        lock.withLock {
            finishedBottleIDs.insert(openItemID)
            finishedCounts[productID, default: 0] += 1
            extraHistory[productID, default: []].insert(
                StockTransaction(
                    id: UUID(), type: .adjustment, delta: -1, quantityBefore: current.quantity,
                    quantityAfter: current.quantity - 1, reason: nil, referenceLabel: "Finished",
                    at: Session.demoNow, byName: byName
                ),
                at: 0
            )
        }
        return .applied(actionID: UUID())
    }

    /// The ids of the product's open bottles, base and opened here, finished ones included.
    private func bottleIDs(of productID: UUID) -> [UUID] {
        guard let summary = store.summary(id: productID) else { return [] }
        let base = summary.tracking == .multiUse
            ? ProductDetail.demoBottles(count: summary.openCount, of: summary.id)
            : []
        let opened = lock.withLock { openedBottles[productID] ?? [] }
        return (opened + base).map(\.id)
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
    /// The detail with other batches: the undated quantity follows them; the status is the summary's.
    func with(batches: [ProductBatch]) -> ProductDetail {
        let undated = batches.filter { $0.expiryMonth == nil }.reduce(Decimal(0)) { $0 + $1.quantity }
        return ProductDetail(
            id: id, name: name, categoryName: categoryName, unit: unit, packUnit: packUnit, packSize: packSize,
            minimum: minimum, target: target, tracking: tracking, location: location, status: status,
            quantity: quantity, unopened: unopened, openCount: openCount, missingExpiryQuantity: max(undated, 0),
            usedInLast30Days: usedInLast30Days, lastCountedAt: lastCountedAt, toBuyItemID: toBuyItemID,
            batches: batches, openBottles: openBottles, history: history, categoryID: categoryID, supplier: supplier
        )
    }

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
    fileprivate nonisolated static func demoID(_ suffix: String) -> UUID {
        UUID(uuidString: "00000000-0000-4000-8000-0000000000\(suffix)") ?? UUID()
    }

    /// The open bottles of a demo product, with ids that end in the product's own last byte and the index,
    /// so every bottle of the clinic has its own id.
    nonisolated static func demoBottles(count: Int, of productID: UUID) -> [OpenBottle] {
        let productByte = String(productID.uuidString.suffix(2))
        return (0..<count).map { index in
            OpenBottle(
                id: UUID(uuidString: "00000000-0000-4000-8000-00000000c\(index)\(productByte)") ?? UUID(),
                openedAt: Session.demoNow.addingTimeInterval(Double(-(index + 1)) * 86_400 * 3),
                openedByName: index == 0 ? "Sarah Mitchell" : "Michael Reyes"
            )
        }
    }

}
