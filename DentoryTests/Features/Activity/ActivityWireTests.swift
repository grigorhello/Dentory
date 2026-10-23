import Foundation
import Testing
@testable import Dentory

/// `activity_alerts` decodes straight into `ActivityAlert`, with a product's alert and a delivery's.
struct ActivityWireTests {
    @Test func theAlertsDecode() throws {
        let json = #"""
        [{"id":"00000000-0000-4000-8000-000000000a94","kind":"expiring","opened_at":"2026-10-01T07:00:00+00:00",
          "threshold_days":60,"product_id":"00000000-0000-4000-8000-0000000000d4","name":"Bonding agent",
          "unit":"bottles","tracking":"multi_use","minimum":0,"quantity":1.00,"unopened":1.00,
          "batch_id":"00000000-0000-4000-8000-000000000601","lot":"BA7","expiry_month":"2026-11-01",
          "expiring_batches":1,"invoice_id":null,"supplier":null},
         {"id":"00000000-0000-4000-8000-000000000a91","kind":"invoice_ready","opened_at":"2026-10-02T12:56:00+00:00",
          "threshold_days":null,"product_id":null,"name":null,"unit":null,"tracking":null,"minimum":null,
          "quantity":null,"unopened":null,"batch_id":null,"lot":null,"expiry_month":null,"expiring_batches":0,
          "invoice_id":"d0000000-0000-4000-8000-000000000401","supplier":"Patterson"}]
        """#
        let alerts = try JSONDecoder.supabase.decode([ActivityAlert].self, from: Data(json.utf8))
        #expect(alerts.map(\.kind) == [.expiring, .invoiceReady])
        #expect(alerts.first?.thresholdDays == 60)
        #expect(alerts.first?.tracking == .multiUse)
        #expect(alerts.first?.expiryMonth == CalendarDay(year: 2026, month: 11, day: 1))
        #expect(alerts.first?.productID == ActivityAlert.demo[1].productID)
        #expect(alerts.last?.supplier == "Patterson")
        #expect(alerts.last?.productID == nil)
    }
}
