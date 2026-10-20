import Foundation
import Testing
@testable import Dentory

/// The usage being edited: what counts as a change, what Save sends and the record it shows meanwhile.
struct ProcedureUsageDraftTests {
    private let rootCanal = ProcedureEventDetail.demo[0]

    private func id(of name: String) -> UUID {
        rootCanal.items.first { $0.name == name }?.id ?? UUID()
    }

    @Test func theRecordedUsageIsNoChange() {
        let draft = ProcedureUsageDraft(recording: rootCanal.items)
        #expect(draft.supplies.count == 8)
        #expect(draft.bottles.count == 4)
        #expect(draft.hasChanges == false)
        #expect(draft.recordedItems == rootCanal.items)
    }

    @Test func plusOneAndMinusOneOnDifferentSuppliesSendBothQuantities() {
        var draft = ProcedureUsageDraft(recording: rootCanal.items)
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        let gloves = id(of: "Nitrile gloves M")
        draft[quantityOf: septocaine] += 1
        draft[quantityOf: gloves] -= 1
        #expect(draft.hasChanges)
        let edit = draft.edit(eventID: rootCanal.id)
        #expect(edit.lines.filter { $0.quantity > 0 }.count == 8)
        #expect(edit.lines.first { $0.productID == septocaine }?.quantity == 3)
        #expect(edit.lines.first { $0.productID == gloves }?.quantity == 1)
        #expect(edit.takeNew.isEmpty)
    }

    @Test func aSupplySetToZeroIsSentAtZeroAndLeavesTheRecord() {
        var draft = ProcedureUsageDraft(recording: rootCanal.items)
        let paperPoints = id(of: "Paper points")
        draft[quantityOf: paperPoints] = -2
        #expect(draft[quantityOf: paperPoints] == 0, "Never below 0")
        let lines = draft.edit(eventID: rootCanal.id).lines
        #expect(lines.contains(ProcedureStartLine(productID: paperPoints, quantity: 0)))
        #expect(draft.recordedItems.contains { $0.id == paperPoints } == false)
    }

    @Test func removingASupplyIsAChange() {
        var draft = ProcedureUsageDraft(recording: rootCanal.items)
        draft.remove(id(of: "Suction tips"))
        #expect(draft.hasChanges)
        #expect(draft.contains(id(of: "Suction tips")) == false)
    }

    @Test func aSupplyRemovedAndAddedBackComesBackAsRecorded() throws {
        var draft = ProcedureUsageDraft(recording: rootCanal.items)
        let suctionTips = id(of: "Suction tips")
        let recorded = try #require(draft.supplies.first { $0.id == suctionTips })
        draft.remove(suctionTips)
        let product = try #require(ProductSummary.demo.first { $0.name == "Suction tips" })
        let added = draft.add(product)
        #expect(added)
        #expect(draft.supplies.first { $0.id == suctionTips } == recorded, "Not \"Recorded 0\"")
        #expect(draft.hasChanges == false, "Nothing differs from the record again")
    }

    @Test func takeNewOnABottleWithNothingUnopenedChangesNothing() {
        var draft = ProcedureUsageDraft(recording: rootCanal.items)
        #expect(draft.toggleTakeNew(id(of: "Root canal sealer")) == .outOfStock)
        #expect(draft.hasChanges == false)
        #expect(draft.toggleTakeNew(id(of: "Surface disinfectant")) == .toggled)
        #expect(draft.edit(eventID: rootCanal.id).takeNew == [id(of: "Surface disinfectant")])
        #expect(draft.toggleTakeNew(UUID()) == nil, "Not on the procedure")
    }
}
