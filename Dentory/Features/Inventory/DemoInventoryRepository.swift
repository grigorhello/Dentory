import Foundation

/// The products of frames f16 and f19 for previews and UI tests.
struct DemoInventoryRepository: InventoryRepository {
    var products = ProductSummary.demo

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        products
    }
}

extension ProductSummary {
    /// Rows of f16 (Admin and Staff) and f19 (Low), with the demo clinic's categories.
    nonisolated static let demo: [ProductSummary] = [
        demo(1, "Septocaine 4% 1:100,000", "Anesthetic", "cartridges", .countable, 54, 54, 0, 20, .healthy),
        demo(2, "Endo file kit #15-40", "Endodontics", "kits", .countable, 1, 1, 0, 3, .low),
        demo(3, "Composite A2", "Restorative", "syringes", .multiUse, 2, 1, 1, 2, .low),
        demo(4, "Bonding agent", "Restorative", "bottles", .multiUse, 1, 0, 1, 0, .expiring),
        demo(5, "Nitrile gloves M", "PPE", "boxes", .countable, 14, 14, 0, 6, .healthy),
        demo(6, "Surface disinfectant", "Sterilization", "bottles", .multiUse, 3, 1, 2, 0, .healthy),
        demo(7, "Rubber dam latex-free", "Endodontics", "sheets", .countable, 0, 0, 0, 10, .outOfStock),
        demo(8, "Gutta percha F2", "Endodontics", "packs", .countable, 7, 7, 0, 3, .missingExpiry),
        demo(9, "Root canal sealer", "Endodontics", "kits", .multiUse, 1, 0, 1, 0, .low),
        demo(10, "Temporary cement", "Restorative", "kits", .multiUse, 1, 0, 1, 0, .low),
        demo(11, "Suction tips", "Disposable", "bags", .countable, 9, 9, 0, 4, .healthy),
        demo(12, "Alginate impression", "Impression", "bags", .multiUse, 4, 3, 1, 1, .healthy)
    ]

    // swiftlint:disable:next function_parameter_count
    private nonisolated static func demo(
        _ number: Int, _ name: String, _ category: String, _ unit: String, _ tracking: TrackingMode,
        _ quantity: Decimal, _ unopened: Decimal, _ openCount: Int, _ minimum: Decimal, _ status: ProductStatus
    ) -> ProductSummary {
        ProductSummary(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-0000000000%02x", 0xd0 + number)) ?? UUID(),
            name: name,
            categoryName: category,
            unit: unit,
            tracking: tracking,
            location: nil,
            quantity: quantity,
            unopened: unopened,
            openCount: openCount,
            minimum: minimum,
            status: status
        )
    }
}
