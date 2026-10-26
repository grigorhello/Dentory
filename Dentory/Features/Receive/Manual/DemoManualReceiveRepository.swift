import Foundation

/// Receive manually without a server: the demo clinic's products from the shared demo store, received in the packs
/// `supabase/seed-demo.sql` gives them (or the New product sheet gave them in this launch), and a receipt that adds to
/// the product there, so Inventory shows it within the same launch (previews, UI tests).
struct DemoManualReceiveRepository: ManualReceiveRepository {
    let store: DemoProductStore

    func products(clinicID: UUID) async throws -> [ReceivableProduct] {
        try await Task.sleep(for: .milliseconds(200))
        return store.products.map { summary in
            let pack = store.pack(of: summary.id)
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
