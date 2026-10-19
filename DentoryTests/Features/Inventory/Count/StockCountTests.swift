import Foundation
import Testing
@testable import Dentory

struct StockCountTests {
    private let septocaine = ProductSummary.demo[0]   // countable, 54 cartridges
    private let composite = ProductSummary.demo[2]    // multi-use, 1 unopened and 1 open
    private let rubberDam = ProductSummary.demo[6]    // countable, 0 sheets

    private func count(_ counted: [UUID: Int] = [:]) -> StockCount {
        StockCount(clinicID: Session.demo.clinicID, userID: Session.demo.userID, counted: counted)
    }

    @Test func aRowStartsAtItsEstimateAndAMultiUseRowAtItsUnopenedStock() {
        let count = count()
        #expect(StockCount.estimate(of: septocaine) == 54)
        #expect(count.value(for: septocaine) == 54)
        #expect(StockCount.estimate(of: composite) == 1, "The open syringe is not counted")
        #expect(count.value(for: composite) == 1)
        #expect(count.isCorrection(septocaine) == false)
    }

    @Test func aChangedValueIsACorrectionAndTheEstimateAgainIsNot() {
        var count = count()
        count.set(52, for: septocaine)
        #expect(count.value(for: septocaine) == 52)
        #expect(count.isCorrection(septocaine))
        count.set(54, for: septocaine)
        #expect(count.isCorrection(septocaine) == false, "Counting the estimate confirms it")
    }

    @Test func aCountIsNeverNegative() {
        var count = count()
        count.set(-1, for: rubberDam)
        #expect(count.value(for: rubberDam) == 0)
        #expect(count.isCorrection(rubberDam) == false)
    }

    @Test func aNegativeEstimateStartsAtZeroWithoutBeingACorrection() {
        let overdrawn = septocaine.counted(-2)
        var count = count()
        #expect(count.value(for: overdrawn) == 0)
        #expect(count.isCorrection(overdrawn) == false)
        count.set(0, for: overdrawn)
        #expect(count.isCorrection(overdrawn), "Counting 0 corrects -2")
    }

    @Test func aFractionalEstimateShowsTheNearestWholeNumberAndAnyCountCorrectsIt() {
        let partial = septocaine.counted(Decimal(string: "12.5") ?? 0)
        var count = count()
        #expect(count.value(for: partial) == 13)
        #expect(count.isCorrection(partial) == false)
        count.set(12, for: partial)
        #expect(count.isCorrection(partial))
    }

    @Test func correctionsKeepTheOrderGivenAndUndoDropsOne() {
        var count = count()
        count.set(2, for: composite)
        count.set(52, for: septocaine)
        count.set(0, for: rubberDam)
        #expect(count.corrections(among: ProductSummary.demo).map(\.name) == [septocaine.name, composite.name])
        count.reset(septocaine.id)
        #expect(count.corrections(among: ProductSummary.demo).map(\.name) == [composite.name])
        #expect(count.value(for: septocaine) == 54)
    }

    @Test func theCountedRowKeepsTheOpenBottlesOfAMultiUseProduct() {
        let counted = composite.counted(3)
        #expect(counted.unopened == 3)
        #expect(counted.quantity == 4)
        #expect(counted.openCount == 1)
        #expect(counted.status == composite.status, "The status is left to the server")
        #expect(septocaine.counted(52).quantity == 52)
    }
}
