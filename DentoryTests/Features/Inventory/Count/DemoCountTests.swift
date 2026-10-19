import Foundation
import Testing
@testable import Dentory

/// The demo clinic behind previews and UI tests applies a count the way the server does.
struct DemoCountTests {
    private let septocaine = ProductSummary.demo[0]
    private let endoKit = ProductSummary.demo[1]
    private let composite = ProductSummary.demo[2]

    @Test func aCountMovesTheListAndShowsOnProductDetail() async throws {
        let store = DemoProductStore()
        let inventory = DemoInventoryRepository(store: store, byName: "Michael Reyes")
        let details = DemoProductDetailRepository(store: store, byName: "Michael Reyes")
        let outcome = try await inventory.applyCount(clinicID: Session.demo.clinicID, counts: [
            CountedQuantity(productID: septocaine.id, counted: 52),
            CountedQuantity(productID: endoKit.id, counted: 4),
            CountedQuantity(productID: composite.id, counted: 1)
        ])
        #expect(outcome != .queued)

        let rows = try await inventory.products(clinicID: Session.demo.clinicID)
        let endoRow = try #require(rows.first { $0.id == endoKit.id })
        #expect(endoRow.quantity == 4)
        #expect(endoRow.status == .missingExpiry, "Three extra kits are undated, so the kit is no longer low")
        #expect(rows.first { $0.id == composite.id } == composite, "Counted at its estimate, so untouched")

        let septocaineDetail = try await details.detail(productID: septocaine.id)
        #expect(septocaineDetail.quantity == 52)
        #expect(septocaineDetail.lastCountedAt == Session.demoNow)
        let row = try #require(septocaineDetail.history.first)
        #expect(row.type == .count)
        #expect(row.quantityBefore == 54)
        #expect(row.quantityAfter == 52)
        #expect(row.byName == "Michael Reyes")
        #expect(row.reason == "Physical count")

        let endoDetail = try await details.detail(productID: endoKit.id)
        #expect(endoDetail.quantity == 4)
        #expect(endoDetail.lastCountedAt == Session.demoNow)
        #expect(endoDetail.history.map(\.type) == [.count])
        #expect(try await details.detail(productID: composite.id).lastCountedAt == nil)
    }

    @Test func aDecreaseBelowTheMinimumMakesTheProductLow() {
        let store = DemoProductStore()
        let changed = store.applyCount(
            [CountedQuantity(productID: septocaine.id, counted: 12)], at: Session.demoNow, by: "Sarah Mitchell"
        )
        #expect(changed == 1)
        #expect(store.summary(id: septocaine.id)?.status == .low)
        #expect(store.countRecords(for: septocaine.id).map(\.delta) == [-42])
    }
}
