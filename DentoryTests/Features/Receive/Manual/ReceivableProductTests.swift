import Foundation
import Testing
@testable import Dentory

/// How a delivery turns into stock (PRD §6.5, the ticket): packs become counted units, the cost becomes a cost per
/// counted unit, and a multi-use product's delivery adds to its unopened ones.
struct ReceivableProductTests {
    @Test func packsBecomeCountedUnits() throws {
        #expect(ReceivableProduct.septocaine.countedQuantity(received: 5) == 250)
        #expect(ReceivableProduct.septocaine.countedQuantity(received: Decimal(25) / 10) == 125)
        #expect(ReceivableProduct.endoKit.countedQuantity(received: 4) == 4, "Received by the unit")
    }

    @Test func theCostIsStoredPerCountedUnitToFourDecimals() throws {
        let perBox = Decimal(4980) / 100
        #expect(ReceivableProduct.septocaine.unitCost(perReceived: perBox) == Decimal(996) / 1000)
        let thirds = ReceivableProduct(
            id: UUID(), name: "Gloves", categoryName: nil, unit: "pairs", packUnit: "pack", packSize: 3,
            tracking: .countable, quantity: 0, unopened: 0, openCount: 0
        )
        #expect(thirds.unitCost(perReceived: 10) == Decimal(33_333) / 10_000, "As the last unit cost keeps it")
        #expect(ReceivableProduct.endoKit.unitCost(perReceived: 45) == 45)
    }

    @Test func aDeliveryAddsToTheUnopenedOnesOfAMultiUseProduct() {
        #expect(ReceivableProduct.septocaine.currentStock == 54)
        #expect(ReceivableProduct.sealer.quantity == 1)
        #expect(ReceivableProduct.sealer.currentStock == 0, "The open kit is not what a delivery adds to")
    }

    @Test func aPackNeedsAUnitAndASizeOfTwoOrMore() {
        #expect(ReceivableProduct.septocaine.pack?.unit == "box")
        #expect(ReceivableProduct.septocaine.pack?.size == 50)
        #expect(ReceivableProduct.endoKit.pack?.size == nil)
        let blank = ReceivableProduct(
            id: UUID(), name: "Bibs", categoryName: nil, unit: "bibs", packUnit: "", packSize: 500,
            tracking: .countable, quantity: 0, unopened: 0, openCount: 0
        )
        #expect(blank.pack?.size == nil, "A blank pack unit is no pack")
    }
}
