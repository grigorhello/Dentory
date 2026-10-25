import Foundation

/// Receive manually without a server: the demo clinic's products from the shared demo store, received in the packs
/// `supabase/seed-demo.sql` gives them (or the New product sheet gave them in this launch), and a receipt that adds to
/// the product there, so Inventory shows it within the same launch (previews, UI tests).
struct DemoManualReceiveRepository: ManualReceiveRepository {
    let store: DemoProductStore

    /// Septocaine in boxes of 50, Nitrile gloves in cases of 10 and Suction tips in cases of 4, as the seed has them.
    private static let packs: [UUID: (unit: String, size: Int)] = [
        ProductSummary.demo[0].id: ("box", 50),
        ProductSummary.demo[4].id: ("case", 10),
        ProductSummary.demo[10].id: ("case", 4)
    ]

    func products(clinicID: UUID) async throws -> [ReceivableProduct] {
        try await Task.sleep(for: .milliseconds(200))
        return store.products.map { summary in
            let pack = store.draft(for: summary.id).map { draft in
                draft.packUnit.flatMap { unit in draft.packSize.map { (unit: unit, size: $0) } }
            } ?? Self.packs[summary.id]
            return ReceivableProduct(
                id: summary.id, name: summary.name, categoryName: summary.categoryName, unit: summary.unit,
                packUnit: pack?.unit, packSize: pack?.size, tracking: summary.tracking, quantity: summary.quantity,
                unopened: summary.unopened, openCount: summary.openCount
            )
        }
    }

    func receive(_ receipt: ManualReceipt) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(200))
        guard store.receive(receipt.quantity, of: receipt.productID, dated: receipt.expiryMonth != nil) else {
            throw AppError.validation(field: nil, message: "the product is archived")
        }
        return .applied(actionID: UUID())
    }
}
