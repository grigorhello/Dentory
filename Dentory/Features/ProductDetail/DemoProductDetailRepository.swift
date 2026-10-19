import Foundation

/// Product detail without a server: Septocaine as f20 draws it, and a plain detail for the other demo
/// products. Add to buy and its Undo are remembered in memory.
final class DemoProductDetailRepository: ProductDetailRepository, @unchecked Sendable {
    private(set) var toBuyItemIDs: [UUID: UUID] = [:]
    private let lock = NSLock()

    func detail(productID: UUID) async throws -> ProductDetail {
        try await Task.sleep(for: .milliseconds(200))
        guard let summary = ProductSummary.demo.first(where: { $0.id == productID }) else { throw AppError.notFound }
        let onToBuy = lock.withLock { toBuyItemIDs[productID] }
        if summary.id == ProductSummary.demo[0].id {
            return ProductDetail.demoSeptocaine(toBuyItemID: onToBuy)
        }
        return ProductDetail(
            id: summary.id, name: summary.name, categoryName: summary.categoryName, unit: summary.unit,
            packUnit: nil, packSize: nil, minimum: summary.minimum, target: summary.minimum * 3,
            tracking: summary.tracking, location: nil, status: summary.status, quantity: summary.quantity,
            unopened: summary.unopened, openCount: summary.openCount, missingExpiryQuantity: 0,
            usedInLast30Days: 0, lastCountedAt: nil, toBuyItemID: onToBuy, batches: [],
            openBottles: summary.tracking == .multiUse ? ProductDetail.demoBottles(count: summary.openCount) : [],
            history: []
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
