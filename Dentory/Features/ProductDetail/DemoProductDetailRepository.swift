import Foundation

/// Product detail without a server: Septocaine as f20 draws it, and a plain detail for the other demo
/// products. Add to buy and its Undo, adjustments and their Undo, bottles opened and finished are
/// remembered in memory, so the figures and the history move the way the server's would.
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
    private let byName: String
    private let lock = NSLock()

    /// `byName` is who the history rows name: the signed-in person of the demo clinic.
    init(byName: String = "Sarah Mitchell") {
        self.byName = byName
    }

    func detail(productID: UUID) async throws -> ProductDetail {
        try await Task.sleep(for: .milliseconds(200))
        guard let summary = ProductSummary.demo.first(where: { $0.id == productID }) else { throw AppError.notFound }
        let onToBuy = lock.withLock { toBuyItemIDs[productID] }
        let delta = lock.withLock { quantityDeltas[productID] ?? 0 }
        let unopenedDelta = lock.withLock { unopenedDeltas[productID] ?? 0 }
        let finishedCount = lock.withLock { finishedCounts[productID] ?? 0 }
        let opened = lock.withLock { openedBottles[productID] ?? [] }
        let finished = lock.withLock { finishedBottleIDs }
        let history = lock.withLock { extraHistory[productID] ?? [] }
        let base: ProductDetail = if summary.id == ProductSummary.demo[0].id {
            ProductDetail.demoSeptocaine(toBuyItemID: onToBuy)
        } else {
            ProductDetail(
                id: summary.id, name: summary.name, categoryName: summary.categoryName, unit: summary.unit,
                packUnit: nil, packSize: nil, minimum: summary.minimum, target: summary.minimum * 3,
                tracking: summary.tracking, location: nil, status: summary.status, quantity: summary.quantity,
                unopened: summary.unopened, openCount: summary.openCount, missingExpiryQuantity: 0,
                usedInLast30Days: 0, lastCountedAt: nil, toBuyItemID: onToBuy, batches: [],
                openBottles: summary.tracking == .multiUse
                    ? ProductDetail.demoBottles(count: summary.openCount, of: summary.id)
                    : [],
                history: []
            )
        }
        let bottles = (opened + base.openBottles).filter { !finished.contains($0.id) }
        return base
            .adjusted(by: delta, history: history + base.history)
            .replacingBottles(bottles, unopenedDelta: unopenedDelta, quantityDelta: -finishedCount)
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
        guard let productID = ProductSummary.demo.map(\.id).first(where: { id in
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
        guard let summary = ProductSummary.demo.first(where: { $0.id == productID }) else { return [] }
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
            ]
        )
    }

    /// A fixed id for the demo rows: `demoID("b1")` is …0000b1.
    private nonisolated static func demoID(_ suffix: String) -> UUID {
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
