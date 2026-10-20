import Foundation

/// Activity without a server: f8's three alerts (Rubber dam out of stock this morning, Bonding agent expiring and
/// Gutta percha F2 missing expiry since yesterday). It remembers being seen, so Home's demo bell loses its dot.
final class DemoActivityRepository: ActivityRepository, @unchecked Sendable {
    private var seen = false
    private let lock = NSLock()

    /// Whether an alert opened after the last look, as Home's demo bell reads it.
    var hasUnseenAlerts: Bool {
        lock.withLock { !seen }
    }

    func alerts(clinicID: UUID) async throws -> [ActivityAlert] {
        try await Task.sleep(for: .milliseconds(200))
        return ActivityAlert.demo
    }

    func markSeen(clinicID: UUID) async throws {
        lock.withLock { seen = true }
    }
}

extension ActivityAlert {
    /// f8, on the frames' October 2 at 9:41 in New York.
    nonisolated static let demo: [ActivityAlert] = [
        demo(
            0x701, .outOfStock, openedAt: 1_790_944_800, product: 0xd7, name: "Rubber dam latex-free", unit: "sheets",
            minimum: 10, quantity: 0
        ),
        demo(
            0x702, .expiring, openedAt: 1_790_838_000, product: 0xd4, name: "Bonding agent", unit: "bottles",
            minimum: 0, quantity: 1, tracking: .multiUse, threshold: 60, lot: "BA7",
            expiryMonth: CalendarDay(year: 2026, month: 11, day: 1)
        ),
        demo(
            0x703, .missingExpiry, openedAt: 1_790_838_000, product: 0xd8, name: "Gutta percha F2", unit: "packs",
            minimum: 3, quantity: 7
        )
    ]

    // swiftlint:disable:next function_parameter_count
    private nonisolated static func demo(
        _ number: Int, _ kind: Kind, openedAt: TimeInterval, product: Int, name: String, unit: String,
        minimum: Decimal, quantity: Decimal, tracking: TrackingMode = .countable, threshold: Int? = nil,
        lot: String? = nil, expiryMonth: CalendarDay? = nil
    ) -> ActivityAlert {
        ActivityAlert(
            id: demoID(number), kind: kind, openedAt: Date(timeIntervalSince1970: openedAt), thresholdDays: threshold,
            productID: demoID(product), name: name, unit: unit, tracking: tracking, minimum: minimum,
            quantity: quantity, unopened: tracking == .multiUse ? quantity : 0, batchID: lot.map { _ in demoID(0x601) },
            lot: lot, expiryMonth: expiryMonth, expiringBatches: kind == .expiring ? 1 : 0, invoiceID: nil,
            supplier: nil
        )
    }

    private nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", number)) ?? UUID()
    }
}
