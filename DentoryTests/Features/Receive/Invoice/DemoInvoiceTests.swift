import Foundation
import Testing
@testable import Dentory

/// The demo clinic behind previews and UI tests reviews its Patterson invoice the way the server does: f23's four
/// lines, settled and reopened as the line functions settle them, kept for the launch, and gone from Receive delivery
/// once discarded.
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

    @Test func aDiscardedInvoiceLeavesReceiveDeliveryAndTakesNoChoice() async throws {
        let invoices = DemoInvoiceRepository(launched: nil)
        let receive = DemoReceiveRepository(withInvoiceBeingRead: false, setAside: { invoices.discarded })
        let lines = try await invoices.invoice(id: DemoInvoiceRepository.readyID).lines
        #expect(try await receive.overview(clinicID: clinicID).invoices.map(\.id) == [DemoInvoiceRepository.readyID])

        try await invoices.discard(invoiceID: DemoInvoiceRepository.readyID, clinicID: clinicID)
        #expect(try await receive.overview(clinicID: clinicID).invoices.isEmpty)
        let refusal = AppError.validation(field: nil, message: "This invoice is no longer waiting for review.")
        await #expect(throws: refusal) {
            try await invoices.skipLine(lines[3].id)
        }
    }
}
