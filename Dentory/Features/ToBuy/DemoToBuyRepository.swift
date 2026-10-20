import Foundation

/// To buy without a server: the demo clinic's list as `supabase/seed-demo.sql` leaves it (f25: Endo file kit,
/// Composite A2 and Rubber dam to buy, five lines ordered on Oct 1, the Alginate received on Sep 26). Changes are
/// kept in memory, so Mark as ordered, Add item, quantities and Remove move the lines the way the server would.
final class DemoToBuyRepository: ToBuyRepository, @unchecked Sendable {
    private var lines: [ToBuyItem]
    private let now: Date
    private let lock = NSLock()

    init(now: Date = Session.demoNow) {
        self.now = now
        lines = ToBuyItem.demo(now: now)
    }

    func items(clinicID: UUID) async throws -> [ToBuyItem] {
        try await Task.sleep(for: .milliseconds(200))
        return lock.withLock { lines }
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await Task.sleep(for: .milliseconds(200))
        return ProductSummary.demo + DemoSupplies.extraProducts
    }

    func add(clinicID: UUID, productID: UUID) async throws -> AddedToBuy {
        try await Task.sleep(for: .milliseconds(200))
        guard let product = (ProductSummary.demo + DemoSupplies.extraProducts).first(where: { $0.id == productID })
        else { throw AppError.notFound }
        return lock.withLock {
            if let line = lines.first(where: { $0.productID == productID && $0.status == .toBuy }) {
                return AddedToBuy(id: line.id, qty: line.buyQuantity, created: false)
            }
            let target = ToBuyItem.demoTargets[product.name] ?? product.minimum * 3
            let line = ToBuyItem(
                id: UUID(), productID: product.id, name: product.name, unit: product.unit, supplier: nil,
                quantity: product.quantity, target: target, buyQuantity: max(target - product.quantity, 1),
                source: .manual, status: .toBuy, createdAt: now, orderedAt: nil, receivedAt: nil
            )
            let end = lines.firstIndex { $0.status != .toBuy } ?? lines.endIndex
            lines.insert(line, at: end)
            return AddedToBuy(id: line.id, qty: line.buyQuantity, created: true)
        }
    }

    func setQuantity(itemID: UUID, quantity: Decimal) async throws {
        try await Task.sleep(for: .milliseconds(100))
        lock.withLock {
            guard let index = lines.firstIndex(where: { $0.id == itemID && $0.status == .toBuy }) else { return }
            lines[index].buyQuantity = quantity
        }
    }

    func remove(itemID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(100))
        lock.withLock { lines.removeAll { $0.id == itemID && $0.status == .toBuy } }
    }

    func markOrdered(clinicID: UUID, itemIDs: [UUID]) async throws -> Int {
        try await Task.sleep(for: .milliseconds(300))
        return lock.withLock {
            let chosen = Set(itemIDs)
            let moved = lines.filter { chosen.contains($0.id) && $0.status == .toBuy }.map { $0.ordered(at: now) }
            lines.removeAll { line in moved.contains { $0.id == line.id } }
            let firstOrdered = lines.firstIndex { $0.status != .toBuy } ?? lines.endIndex
            lines.insert(contentsOf: moved, at: firstOrdered)
            return moved.count
        }
    }
}

extension ToBuyItem {
    /// The same line, marked ordered at `date`.
    nonisolated func ordered(at date: Date) -> ToBuyItem {
        ToBuyItem(
            id: id, productID: productID, name: name, unit: unit, supplier: supplier, quantity: quantity,
            target: target, buyQuantity: buyQuantity, source: source, status: .ordered, createdAt: createdAt,
            orderedAt: date, receivedAt: nil
        )
    }

    /// Targets of the seed's products, for Add item's suggestion.
    nonisolated static let demoTargets: [String: Decimal] = [
        "Septocaine 4% 1:100,000": 60, "Endo file kit #15-40": 5, "Composite A2": 6, "Bonding agent": 3,
        "Nitrile gloves M": 20, "Surface disinfectant": 4, "Rubber dam latex-free": 36, "Gutta percha F2": 10,
        "Root canal sealer": 2, "Temporary cement": 2, "Suction tips": 12, "Alginate impression": 6,
        "Needle 27g short": 100, "Prophy angle": 100, "Gauze": 10
    ]

    /// The demo ids: products as `ProductSummary.demo` and `DemoSupplies` number them, lines from 0x501.
    nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-000000000%03x", number)) ?? UUID()
    }

    /// The demo clinic's lines at `now` (Thursday, October 2 in the frames).
    nonisolated static func demo(now: Date) -> [ToBuyItem] {
        let day: TimeInterval = 24 * 60 * 60
        let orderedAt = now.addingTimeInterval(-(day - 7 * 3600))
        let receivedAt = now.addingTimeInterval(-6 * day)
        // swiftlint:disable:next large_tuple
        let rows: [(Int, String, String, String?, Decimal, Decimal, Decimal, Status)] = [
            (0xd2, "Endo file kit #15-40", "kits", "Patterson", 1, 5, 4, .toBuy),
            (0xd3, "Composite A2", "syringes", "Patterson", 2, 6, 4, .toBuy),
            (0xd7, "Rubber dam latex-free", "sheets", "Henry Schein", 0, 36, 36, .toBuy),
            (0x208, "Gauze", "packs", "Patterson", 8, 10, 5, .ordered),
            (0x201, "Needle 27g short", "needles", "Patterson", 40, 100, 60, .ordered),
            (0x203, "Prophy angle", "angles", "Patterson", 30, 100, 70, .ordered),
            (0xd9, "Root canal sealer", "kits", "Henry Schein", 1, 2, 1, .ordered),
            (0xda, "Temporary cement", "kits", "Patterson", 1, 2, 1, .ordered),
            (0xdc, "Alginate impression", "bags", "Patterson", 4, 6, 2, .received)
        ]
        return rows.enumerated().map { index, row in
            ToBuyItem(
                id: demoID(0x501 + index), productID: demoID(row.0),
                name: row.1, unit: row.2, supplier: row.3, quantity: row.4, target: row.5, buyQuantity: row.6,
                source: .auto, status: row.7, createdAt: now.addingTimeInterval(-30 * day),
                orderedAt: row.7 == .toBuy ? nil : (row.7 == .received ? receivedAt : orderedAt),
                receivedAt: row.7 == .received ? receivedAt : nil
            )
        }
    }
}
