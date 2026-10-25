import Foundation
import Testing
@testable import Dentory

/// The demo clinic behind previews and UI tests receives the way the server does: packs as the seed has them, and the
/// delivery in the Inventory list of the same launch.
struct DemoManualReceiveTests {
    private let septocaine = ProductSummary.demo[0]
    private let endoKit = ProductSummary.demo[1]

    @Test func theProductsCarryTheSeedsPacksAndTheSheetsOnes() async throws {
        let store = DemoProductStore()
        let repository = DemoManualReceiveRepository(store: store)
        let draft = ProductDraft(
            name: "Articaine 4%", categoryID: nil, unit: "cartridges", packUnit: "box", packSize: 50,
            tracking: .countable, minimum: 10, target: 40, supplier: nil, location: nil
        )
        let created = store.create(draft)

        let products = try await repository.products(clinicID: Session.demo.clinicID)
        #expect(products.count == ProductSummary.demo.count + 1)
        let septocaineRow = try #require(products.first { $0.id == septocaine.id })
        #expect(septocaineRow.packUnit == "box" && septocaineRow.packSize == 50)
        #expect(products.first { $0.id == endoKit.id }?.packUnit == nil)
        let articaine = try #require(products.first { $0.id == created })
        #expect(articaine.packUnit == "box" && articaine.packSize == 50 && articaine.quantity == 0)
    }

    @Test func aDeliveryShowsInTheInventoryList() async throws {
        let store = DemoProductStore()
        let repository = DemoManualReceiveRepository(store: store)
        let outcome = try await repository.receive(ManualReceipt(
            clinicID: Session.demo.clinicID, productID: endoKit.id, quantity: 4, unitCost: 45, lot: nil,
            expiryMonth: nil
        ))
        #expect(outcome != .queued)
        let rows = try await DemoInventoryRepository(store: store).products(clinicID: Session.demo.clinicID)
        let row = try #require(rows.first { $0.id == endoKit.id })
        #expect(row.quantity == 5)
        #expect(row.status == .missingExpiry, "No longer low; the four kits came without an expiry")

        _ = try await repository.receive(ManualReceipt(
            clinicID: Session.demo.clinicID, productID: septocaine.id, quantity: 250, unitCost: nil, lot: "L-77",
            expiryMonth: CalendarDay(year: 2027, month: 3, day: 1)
        ))
        let septocaineRow = try #require(store.summary(id: septocaine.id))
        #expect(septocaineRow.quantity == 304)
        #expect(septocaineRow.status == .healthy, "Dated, so nothing is missing an expiry")
    }

    @Test func aDeletedProductIsRefused() async {
        let store = DemoProductStore()
        _ = store.archive(id: endoKit.id)
        let repository = DemoManualReceiveRepository(store: store)
        await #expect(throws: AppError.self) {
            try await repository.receive(ManualReceipt(
                clinicID: Session.demo.clinicID, productID: endoKit.id, quantity: 1, unitCost: nil, lot: nil,
                expiryMonth: nil
            ))
        }
    }
}
