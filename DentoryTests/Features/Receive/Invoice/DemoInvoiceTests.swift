import Foundation
import Testing
@testable import Dentory

/// The demo clinic behind previews and UI tests reviews its Patterson invoice the way the server does: f23's four
/// lines, settled and reopened as the line functions settle them, kept for the launch, gone from Receive delivery once
/// discarded or received, and received into the shared demo products until Undo (MS-131).
@MainActor
struct DemoInvoiceTests {
    private let clinicID = Session.demo.clinicID

    @Test func theFramesInvoiceHasF23sFourLines() async throws {
        let repository = DemoInvoiceRepository(launched: nil)
        let invoice = try await repository.invoice(id: DemoInvoiceRepository.readyID)
        #expect(invoice.lines.map(\.raw) == [
            "SEPTO 4% 1:100K 50/BX", "ENDO FILE KIT 15-40 21MM", "TEMPBOND NE 1PK", "HANDLING / FUEL SURCHARGE"
        ])
        #expect(invoice.lines.map(\.state) == [.matched, .possibleMatch, .newProduct, .needsReview])
        #expect(invoice.lines.map(\.number) == [1, 2, 3, 4])
        #expect(invoice.lines[0].productName == "Septocaine 4% 1:100,000")
        #expect(invoice.lines[1].suggestedProductName == "Endo file kit #15-40")
        #expect(invoice.lineCount == 4)
    }

    @Test func linesAreSettledAsTheServerSettlesThemAndStaySo() async throws {
        let store = DemoProductStore()
        let repository = DemoInvoiceRepository(launched: nil, store: store)
        let lines = try await repository.invoice(id: DemoInvoiceRepository.readyID).lines
        let endoKit = ProductSummary.demo[1].id

        let matched = try await repository.matchLine(lines[1].id, to: endoKit)
        #expect(matched.state == .matched && matched.productName == "Endo file kit #15-40")
        await #expect(throws: AppError.validation(field: nil, message: "This line is already resolved.")) {
            try await repository.matchLine(lines[1].id, to: endoKit)
        }
        let draft = ProductDraft(
            name: "Temp-Bond NE", categoryID: nil, unit: "packs", packUnit: nil, packSize: nil, tracking: .countable,
            minimum: 0, target: 0, supplier: nil, location: nil
        )
        let created = try await repository.createLine(lines[2].id, as: store.create(draft))
        #expect(created.state == .created && created.productName == "Temp-Bond NE")
        _ = try await repository.skipLine(lines[3].id)
        let batch = try await repository.setBatch(
            of: lines[0].id, lot: " A112 ", expiryMonth: CalendarDay(year: 2028, month: 3, day: 1)
        )
        #expect(batch.lot == "A112")

        let again = try await repository.invoice(id: DemoInvoiceRepository.readyID)
        #expect(again.lines.map(\.state) == [.matched, .matched, .created, .skipped], "Kept for the launch")
        let reopened = try await repository.reopenLine(lines[2].id)
        #expect(reopened.state == .newProduct && reopened.productID == nil)
        #expect(try await repository.reopenLine(lines[0].id).productName == "Septocaine 4% 1:100,000")
    }

    /// The decision on #101: a line read as Matched takes another product and reopens to the one it was read as; a
    /// Possible match is pointed at another product than its suggestion.
    @Test func aMatchedLineAndAPossibleMatchTakeAnotherProductAsTheServerAllows() async throws {
        let repository = DemoInvoiceRepository(launched: nil, store: DemoProductStore())
        let lines = try await repository.invoice(id: DemoInvoiceRepository.readyID).lines
        let septocaine = ProductSummary.demo[0]
        let rubberDam = ProductSummary.demo[6]
        let gutta = ProductSummary.demo[7]

        let changed = try await repository.matchLine(lines[0].id, to: gutta.id)
        #expect(changed.productName == "Gutta percha F2" && changed.readProductID == septocaine.id)
        #expect(changed.isMatchChanged)
        let reopened = try await repository.reopenLine(lines[0].id)
        #expect(reopened.productID == septocaine.id && reopened.productName == "Septocaine 4% 1:100,000")
        await #expect(throws: AppError.validation(field: nil, message: "This line is already resolved.")) {
            try await repository.createLine(lines[0].id, as: rubberDam.id)
        }

        let pointed = try await repository.matchLine(lines[1].id, to: rubberDam.id)
        #expect(pointed.state == .matched && pointed.productName == "Rubber dam latex-free")
        await #expect(throws: AppError.validation(field: nil, message: "This line is already resolved.")) {
            try await repository.matchLine(lines[1].id, to: gutta.id)
        }
        let suggestion = try await repository.reopenLine(lines[1].id)
        #expect(suggestion.state == .possibleMatch && suggestion.productID == nil)
        #expect(suggestion.suggestedProductName == "Endo file kit #15-40")
    }

    @Test func aDiscardedInvoiceLeavesReceiveDeliveryAndTakesNoChoice() async throws {
        let invoices = DemoInvoiceRepository(launched: nil)
        let receive = DemoReceiveRepository(added: nil, settled: { invoices.settled })
        let lines = try await invoices.invoice(id: DemoInvoiceRepository.readyID).lines
        #expect(try await receive.overview(clinicID: clinicID).invoices.map(\.id) == [DemoInvoiceRepository.readyID])

        try await invoices.discard(invoiceID: DemoInvoiceRepository.readyID, clinicID: clinicID)
        #expect(try await receive.overview(clinicID: clinicID).invoices.isEmpty)
        let refusal = AppError.validation(field: nil, message: "This invoice is no longer waiting for review.")
        await #expect(throws: refusal) {
            try await invoices.skipLine(lines[3].id)
        }
    }

    @Test func confirmingTheFramesInvoiceAddsTheDeliveryAndUndoTakesItBack() async throws {
        let store = DemoProductStore()
        let invoices = DemoInvoiceRepository(launched: nil, store: store)
        let receive = DemoReceiveRepository(added: nil, settled: { invoices.settled })
        let invoiceID = DemoInvoiceRepository.readyID
        let lines = try await invoices.invoice(id: invoiceID).lines
        let septocaine = ProductSummary.demo[0].id
        let endoKit = ProductSummary.demo[1].id
        await #expect(throws: AppError.validation(field: nil, message: "Resolve every line to continue.")) {
            try await invoices.confirm(invoiceID: invoiceID)
        }
        let draft = ProductDraft(
            name: "Temp-Bond NE", categoryID: nil, unit: "packs", packUnit: nil, packSize: nil, tracking: .countable,
            minimum: 0, target: 0, supplier: nil, location: nil
        )
        let tempBond = store.create(draft)
        _ = try await invoices.matchLine(lines[1].id, to: endoKit)
        _ = try await invoices.createLine(lines[2].id, as: tempBond)
        _ = try await invoices.skipLine(lines[3].id)

        let outcome = try await invoices.confirm(invoiceID: invoiceID)
        #expect(store.summary(id: septocaine)?.quantity == 304, "5 boxes of 50 cartridges")
        #expect(store.summary(id: endoKit)?.quantity == 5, "4 kits, which come one by one")
        #expect(store.summary(id: tempBond)?.quantity == 1)
        let received = try await invoices.invoice(id: invoiceID)
        #expect(received.status == .confirmed && received.confirmedByName == "Sarah Mitchell")
        #expect(try await receive.overview(clinicID: clinicID).invoices.isEmpty, "No longer to continue reviewing")
        await #expect(throws: AppError.validation(field: nil, message: "This delivery was already received.")) {
            try await invoices.discard(invoiceID: invoiceID, clinicID: clinicID)
        }

        guard case .applied(let actionID?) = outcome else {
            Issue.record("No action to undo")
            return
        }
        try await invoices.undoConfirm(actionID: actionID)
        #expect(store.summary(id: septocaine)?.quantity == 54)
        #expect(store.summary(id: endoKit)?.quantity == 1)
        #expect(try await invoices.invoice(id: invoiceID).status == .ready, "Back in review")
        #expect(try await receive.overview(clinicID: clinicID).invoices.map(\.id) == [invoiceID])
    }
}
