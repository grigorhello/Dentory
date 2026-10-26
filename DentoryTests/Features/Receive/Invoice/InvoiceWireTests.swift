import Foundation
import Testing
@testable import Dentory

/// `invoice_detail` and `invoice_create` decode straight into `InvoiceSummary`, and the line functions into
/// `InvoiceLine`, as the local database answers them.
struct InvoiceWireTests {
    @Test func anInvoiceToReviewDecodesWithItsLines() throws {
        let json = #"""
        {"id": "d0000000-0000-4000-8000-000000000401", "total": 449.00, "number": "INV-10092", "source": "camera",
         "status": "ready", "read_at": "2026-10-26T05:10:04.697739+00:00", "currency": "CAD", "supplier": "Patterson",
         "created_at": "2026-10-26T05:10:04.697739+00:00", "line_count": 2, "invoice_date": "2026-10-24",
         "failure_reason": null, "reading_started": true, "lines": [
          {"n": 1, "id": "ec29548f-c54b-4241-a568-2ef0e40c543f", "lot": "B441", "qty": 5.00,
           "raw": "SEPTO 4% 1:100K 50/BX", "kind": "product", "unit": "boxes", "state": "matched", "line_total": 249.00,
           "product_id": "d0000000-0000-4000-8000-000000000201", "read_state": "matched", "unit_price": 49.8000,
           "expiry_month": "2028-03-01", "product_name": "Septocaine 4% 1:100,000", "suggested_name": "Septo 4% 1:100K",
           "suggested_unit": "boxes", "suggested_product_id": null, "suggested_product_name": null},
          {"n": 4, "id": "ad4e1068-941b-42ae-be4f-d50ca3237ab4", "lot": null, "qty": 1.00,
           "raw": "HANDLING / FUEL SURCHARGE", "kind": "fee", "unit": null, "state": "skipped", "line_total": 4.80,
           "product_id": null, "read_state": "needs_review", "unit_price": 4.8000, "expiry_month": null,
           "product_name": null, "suggested_name": "Handling / fuel surcharge", "suggested_unit": "units",
           "suggested_product_id": null, "suggested_product_name": null}]}
        """#
        let invoice = try JSONDecoder.supabase.decode(InvoiceSummary.self, from: Data(json.utf8))
        #expect(invoice.lines.count == 2)
        let septo = try #require(invoice.lines.first)
        #expect(septo.number == 1)
        #expect(septo.state == .matched && septo.readState == .matched)
        #expect(septo.productID == UUID(uuidString: "d0000000-0000-4000-8000-000000000201"))
        #expect(septo.productName == "Septocaine 4% 1:100,000")
        #expect(septo.qty == 5 && septo.unitPrice == Decimal(string: "49.8") && septo.lineTotal == 249)
        #expect(septo.lot == "B441" && septo.expiryMonth == CalendarDay(year: 2028, month: 3, day: 1))
        let fee = try #require(invoice.lines.last)
        #expect(fee.kind == .fee && fee.unit == nil)
        #expect(fee.state == .skipped && fee.readState == .needsReview && fee.canReopen)
        #expect(fee.suggestedName == "Handling / fuel surcharge")
    }

    @Test func aLineFunctionsAnswerDecodesWithItsSuggestion() throws {
        let json = #"""
        {"n": 2, "id": "88d8a3aa-268d-4e9e-b809-08606a20fb11", "lot": null, "qty": 4.00,
         "raw": "ENDO FILE KIT 15-40 21MM", "kind": "product", "unit": "boxes", "state": "possible_match",
         "line_total": 180.00, "product_id": null, "read_state": "possible_match", "unit_price": 45.0000,
         "expiry_month": null, "product_name": null, "suggested_name": "Endo file kit 15-40 21MM",
         "suggested_unit": "boxes", "suggested_product_id": "d0000000-0000-4000-8000-000000000202",
         "suggested_product_name": "Endo file kit #15-40"}
        """#
        let line = try JSONDecoder.supabase.decode(InvoiceLine.self, from: Data(json.utf8))
        #expect(line.state == .possibleMatch && !line.isResolved && !line.canReopen)
        #expect(line.suggestedProductID == UUID(uuidString: "d0000000-0000-4000-8000-000000000202"))
        #expect(line.suggestedProductName == "Endo file kit #15-40")
        #expect(line.productID == nil)
    }

    @Test func everyLineStateTheServerKeepsDecodes() throws {
        for state in ["matched", "possible_match", "new_product", "needs_review", "created", "skipped"] {
            let json = """
            {"n": 1, "id": "88d8a3aa-268d-4e9e-b809-08606a20fb11", "raw": "X", "kind": "product", "state": "\(state)",
             "read_state": "new_product"}
            """
            let line = try JSONDecoder.supabase.decode(InvoiceLine.self, from: Data(json.utf8))
            #expect(line.state.rawValue == state)
        }
    }

    @Test func aReadInvoiceDecodesWithItsHeaderAndLineCount() throws {
        let json = #"""
        {"id": "377fac63-f4f5-4acd-b32b-a7c6980ec6b0", "total": 520.03, "number": "INV-10092", "source": "file",
         "status": "ready", "read_at": "2026-10-26T02:16:31.424351+00:00", "currency": "CAD",
         "supplier": "Northbridge Dental Supply", "created_at": "2026-10-26T02:16:29.602013+00:00", "line_count": 4,
         "invoice_date": "2026-09-30", "failure_reason": null, "reading_started": true}
        """#
        let invoice = try JSONDecoder.supabase.decode(InvoiceSummary.self, from: Data(json.utf8))
        #expect(invoice == InvoiceSummary(
            id: UUID(uuidString: "377fac63-f4f5-4acd-b32b-a7c6980ec6b0") ?? UUID(), status: .ready,
            supplier: "Northbridge Dental Supply", number: "INV-10092", total: Decimal(string: "520.03"),
            currency: "CAD", readingStarted: true, lineCount: 4
        ))
    }

    @Test func anInvoiceBeingReadDecodesWithNothingReadYet() throws {
        let json = #"""
        {"id": "620f5ce8-d5d0-4a3d-81cb-3bce0d0dd5ab", "total": null, "number": null, "source": "camera",
         "status": "reading", "read_at": null, "currency": null, "supplier": null,
         "created_at": "2026-10-26T02:15:41.72122+00:00", "line_count": 0, "invoice_date": null,
         "failure_reason": null, "reading_started": false}
        """#
        let invoice = try JSONDecoder.supabase.decode(InvoiceSummary.self, from: Data(json.utf8))
        #expect(invoice.status == .reading)
        #expect(!invoice.readingStarted)
        #expect(invoice.supplier == nil && invoice.total == nil && invoice.lineCount == 0)
    }

    @Test func everyStateTheServerKeepsDecodes() throws {
        for status in ["reading", "ready", "failed", "confirmed", "discarded"] {
            let json = """
            {"id": "620f5ce8-d5d0-4a3d-81cb-3bce0d0dd5ab", "status": "\(status)", "supplier": null, "number": null,
             "total": null, "currency": null, "reading_started": true, "line_count": 0}
            """
            let invoice = try JSONDecoder.supabase.decode(InvoiceSummary.self, from: Data(json.utf8))
            #expect(invoice.status.rawValue == status)
        }
    }
}
