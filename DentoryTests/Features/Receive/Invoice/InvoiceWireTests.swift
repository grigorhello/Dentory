import Foundation
import Testing
@testable import Dentory

/// `invoice_detail` and `invoice_create` decode straight into `InvoiceSummary`, as the local database answers them.
struct InvoiceWireTests {
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
