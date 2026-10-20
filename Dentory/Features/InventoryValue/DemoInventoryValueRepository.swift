import Foundation

/// The figures of f10 for previews and UI tests, on the demo products and categories.
struct DemoInventoryValueRepository: InventoryValueRepository {
    var value = InventoryValue.demo

    func value(clinicID: UUID) async throws -> InventoryValue {
        value
    }
}

extension InventoryValue {
    /// f10 as drawn: $12,420 with $186 expiring, $2,140 used and $1,890 received, six categories and five products.
    nonisolated static let demo = InventoryValue(
        total: 12_420,
        atRisk90: 186,
        used30: 2_140,
        received30: 1_890,
        uncostedCount: 0,
        categories: [
            category(1, "Anesthetic", 4_860, 3),
            category(2, "Restorative", 2_410, 8),
            category(3, "Endodontics", 2_180, 6),
            category(4, "PPE", 1_540, 1),
            category(5, "Sterilization", 830, 1),
            category(6, "Other", 600, 2)
        ],
        topProducts: [
            product("Septocaine 4% 1:100,000", 54, cents: 180),
            product("Composite A2", 2, cents: 4_200),
            product("Bonding agent", 1, cents: 8_200),
            product("Nitrile gloves M", 14, cents: 560),
            product("Endo file kit #15-40", 1, cents: 4_500)
        ]
    )

    private nonisolated static func category(
        _ number: Int, _ name: String, _ value: Decimal, _ productCount: Int
    ) -> InventoryValueCategory {
        InventoryValueCategory(
            categoryID: UUID(uuidString: String(format: "00000000-0000-4000-8000-0000000000%02x", 0xc0 + number)),
            name: name,
            value: value,
            productCount: productCount
        )
    }

    /// One of the demo inventory's products, by name, so a tap opens its demo Product detail. The cost comes in
    /// cents so it stays exact ("$1.80").
    private nonisolated static func product(_ name: String, _ quantity: Decimal, cents: Int) -> InventoryValueProduct {
        let summary = ProductSummary.demo.first { $0.name == name }
        let unitCost = Decimal(cents) / 100
        return InventoryValueProduct(
            productID: summary?.id ?? UUID(),
            name: name,
            unit: summary?.unit ?? "",
            quantity: quantity,
            unitCost: unitCost,
            value: quantity * unitCost
        )
    }
}
