import Foundation

extension ActivityHistoryEntry {
    /// The demo clinic's ledger up to the frames' October 2 in New York, as the seed tells it: yesterday's count of
    /// Septocaine at 4:22 PM (f9), Root canal at 3:14 PM (Home's Latest) and Cleaning, the Filling, a delivery and a
    /// damaged syringe the day before, bottles opened and the Alginate delivery. Septocaine's own history is Product
    /// detail's three rows (f20), its 2 cartridges part of that Root canal.
    nonisolated static func demo(productID: UUID?) -> [ActivityHistoryEntry] {
        guard let productID else { return clinic }
        if productID == ProductSummary.demo[0].id { return septocaine }
        return clinic.filter { $0.productID == productID }
    }

    private nonisolated static let septocaineCount = entry(
        0xf1, at: 1_790_886_120, .count, "Septocaine 4% 1:100,000", product: 0xd1, delta: -2, before: 43,
        label: "Physical count", by: "Michael Reyes"
    )

    private nonisolated static let septocaineDelivery = entry(
        0xf3, at: 1_790_791_500, .receiving, "Septocaine 4% 1:100,000", product: 0xd1, delta: 40,
        refType: "invoice", label: "Invoice INV-10092", by: "Michael Reyes"
    )

    private nonisolated static let clinic: [ActivityHistoryEntry] = [
        septocaineCount,
        group(0xe1, at: 1_790_882_040, "Root canal", delta: -10, by: "Sarah Mitchell"),
        group(0xe2, at: 1_790_868_000, "Cleaning", delta: -5, by: "Michael Reyes"),
        septocaineDelivery,
        group(0xe3, at: 1_790_791_500, "Filling", delta: -8, by: "Sarah Mitchell"),
        entry(0x802, at: 1_790_791_320, .adjustment, "Composite A2", product: 0xd3, delta: -1, label: "Damaged",
              reason: "Damaged", by: "Sarah Mitchell"),
        entry(0x803, at: 1_790_683_500, .adjustment, "Surface disinfectant", product: 0xd6, delta: 0,
              label: "Opened a new bottle", by: "Sarah Mitchell"),
        entry(0x804, at: 1_790_625_000, .adjustment, "Impression material PVS", product: 0x8f1, delta: 0,
              label: "Opened a new bottle", by: "Dr. Daniel Kim"),
        entry(0x805, at: 1_790_437_200, .receiving, "Alginate impression", product: 0xdc, delta: 2,
              label: "Receive manually", by: "Sarah Mitchell")
    ]

    private nonisolated static let septocaine: [ActivityHistoryEntry] = [
        septocaineCount,
        entry(0xf2, at: 1_790_882_040, .procedure, "Septocaine 4% 1:100,000", product: 0xd1, delta: -2,
              refType: "procedure_event", label: "Root canal", by: "Sarah Mitchell"),
        septocaineDelivery
    ]

    // swiftlint:disable:next function_parameter_count
    private nonisolated static func entry(
        _ number: Int, at seconds: TimeInterval, _ type: TransactionType, _ subject: String, product: Int,
        delta: Decimal, before: Decimal? = nil, refType: String = "manual", label: String, reason: String? = nil,
        by name: String
    ) -> ActivityHistoryEntry {
        ActivityHistoryEntry(
            id: demoID(number), at: Date(timeIntervalSince1970: seconds), type: type, subject: subject,
            productID: demoID(product), delta: delta, qtyBefore: before, qtyAfter: before.map { $0 + delta },
            refType: type == .count ? "count_session" : refType, refLabel: label, reason: reason, note: nil,
            isEdit: false, byName: name
        )
    }

    /// A procedure started, its rows summed; the id is the procedure's, as the server names a start's action.
    private nonisolated static func group(
        _ event: Int, at seconds: TimeInterval, _ name: String, delta: Decimal, by person: String
    ) -> ActivityHistoryEntry {
        ActivityHistoryEntry(
            id: demoID(event), at: Date(timeIntervalSince1970: seconds), type: .procedure, subject: name,
            productID: nil, delta: delta, qtyBefore: nil, qtyAfter: nil, refType: "procedure_event", refLabel: name,
            reason: nil, note: nil, isEdit: false, byName: person
        )
    }

    private nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", number)) ?? UUID()
    }
}
