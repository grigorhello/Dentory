import Foundation
import Supabase
import Testing
@testable import Dentory

/// PostgREST answers in snake_case with ISO 8601 instants; every row type the app reads must decode
/// through the decoder the client is configured with.
struct SupabaseRowDecodingTests {
    private let decoder = SupabaseClientProvider.options.db.decoder

    @Test func theClientDecodesWithTheAppDecoder() {
        #expect(decoder === JSONDecoder.supabase)
        #expect(SupabaseClientProvider.options.db.encoder === JSONEncoder.supabase)
    }

    @Test func clinicAttentionRow() throws {
        let json = #"""
        {"clinic_id":"d0000000-0000-4000-8000-000000000001","to_buy_count":3,"expiring_batch_count":2,
         "missing_expiry_product_count":1,"inventory_value":1615.59,"value_at_risk_90":186.04}
        """#
        let row = try decoder.decode(HomeAttentionRow.self, from: Data(json.utf8))
        #expect(row.toBuyCount == 3)
        #expect(row.expiringBatchCount == 2)
        #expect(row.missingExpiryProductCount == 1)
        #expect(row.inventoryValue == Decimal(string: "1615.59"))
        #expect(row.valueAtRisk90 == Decimal(string: "186.04"))
    }

    @Test func procedureEventRowWithItemCount() throws {
        let json = #"""
        [{"id":"d0000000-0000-4000-8000-000000000e01","name":"Root canal","started_at":"2026-10-01T19:14:00+00:00",
          "started_by":"d0000000-0000-4000-8000-000000000a01","procedure_event_items":[{"count":12}]}]
        """#
        let rows = try decoder.decode([HomeEventRow].self, from: Data(json.utf8))
        #expect(rows.first?.name == "Root canal")
        #expect(rows.first?.procedureEventItems.first?.count == 12)
        #expect(rows.first?.startedAt == Date(timeIntervalSince1970: 1_790_882_040))
    }

    @Test func memberAlertAndReadRows() throws {
        let member = try decoder.decode([HomeMemberRow].self, from: Data(#"[{"full_name":"Sarah Mitchell"}]"#.utf8))
        #expect(member.first?.fullName == "Sarah Mitchell")
        let alert = try decoder.decode(
            [HomeAlertRow].self, from: Data(#"[{"opened_at":"2026-10-02T12:56:00.123456+00:00"}]"#.utf8)
        )
        #expect(alert.first != nil)
        let readJSON = #"[{"last_seen_at":"2026-10-02T07:00:00Z"}]"#
        let read = try decoder.decode([HomeReadRow].self, from: Data(readJSON.utf8))
        #expect(read.first?.lastSeenAt == Date(timeIntervalSince1970: 1_790_924_400))
    }

    @Test func membershipRowForSignIn() throws {
        let json = #"""
        {"role":"admin","full_name":"Sarah Mitchell",
         "clinic":{"id":"d0000000-0000-4000-8000-000000000001","name":"Smile Dental","currency":"CAD",
                   "time_zone":"America/Toronto"}}
        """#
        let row = try decoder.decode(MembershipRow.self, from: Data(json.utf8))
        #expect(row.fullName == "Sarah Mitchell")
        #expect(row.clinic.timeZone == "America/Toronto")
        #expect(row.role == .admin)
    }

    @Test func categoryRowsAndTheFindOrCreateAnswer() throws {
        let rows = try decoder.decode(
            [ProductCategory].self,
            from: Data(#"[{"id":"00000000-0000-4000-8000-0000000000c0","name":"Anesthetic"}]"#.utf8)
        )
        #expect(rows.first?.name == "Anesthetic")
        let created = try decoder.decode(
            ProductCategory.self,
            from: Data(#"{"id":"00000000-0000-4000-8000-0000000000c9","name":"Orthodontics"}"#.utf8)
        )
        #expect(created.id == UUID(uuidString: "00000000-0000-4000-8000-0000000000c9"))
        let inserted = try decoder.decode(
            ProductIDRow.self, from: Data(#"{"id":"d0000000-0000-4000-8000-000000000301"}"#.utf8)
        )
        #expect(inserted.id == UUID(uuidString: "d0000000-0000-4000-8000-000000000301"))
    }

    /// The answer `product_detail` gave for the seeded Surface disinfectant (`make seed-demo`), with the count
    /// and To buy fields filled in the same formats: timestamps with an offset, numerics with a fraction, a
    /// `date` for the expiry month. `used_in_30_days` is named so no key component starts with a digit.
    @Test func productDetailAnswer() throws {
        let json = #"""
        {"batches":[{"id":"d18adbd4-691e-458b-975a-26aef9a2bb40","lot":null,"qty":1.0,
        "expiry_month":"2028-06-01"}],"history":[{"at":"2026-10-16T12:05:00+00:00",
        "id":"a770e99a-5f22-4c49-98eb-d4e162e9a5b3","type":"adjustment","delta":0.0,"reason":null,
        "by_name":"Sarah Mitchell","qty_after":3.0,"ref_label":"Opened a new bottle","qty_before":3.0},
        {"at":"2026-09-25T12:10:00+00:00","id":"8eca3ec2-7e86-44f5-bfea-2de5c30f5a4e","type":"adjustment",
        "delta":0.0,"reason":null,"by_name":"Michael Reyes","qty_after":3.0,
        "ref_label":"Opened a new bottle","qty_before":3.0}],
        "product":{"id":"d0000000-0000-4000-8000-000000000206","name":"Surface disinfectant",
        "category_id":"00000000-0000-4000-8000-0000000000c7","supplier":"Benco",
        "unit":"bottles","status":"healthy","target":4.0,"minimum":0.0,"location":"Sterilization · Cabinet",
        "quantity":3.0,"tracking":"multi_use","unopened":1.0,"pack_size":null,"pack_unit":null,
        "open_count":2,"category_name":"Sterilization","missing_expiry_qty":0.0},
        "open_items":[{"id":"f7fe2d73-9682-48c6-a5cb-4d8cb2897081","opened_at":"2026-10-16T12:05:00+00:00",
        "opened_by_name":"Sarah Mitchell"},{"id":"5f1db708-3748-4420-bf64-726a1b278a34",
        "opened_at":"2026-09-25T12:10:00+00:00","opened_by_name":"Michael Reyes"}],
        "to_buy_item_id":"e0000000-0000-4000-8000-000000000301",
        "last_counted_at":"2026-10-01T13:41:00+00:00","used_in_30_days":3.0}
        """#
        let payload = try decoder.decode(ProductDetailPayload.self, from: Data(json.utf8))
        let product = try #require(payload.product)
        #expect(product.id == UUID(uuidString: "d0000000-0000-4000-8000-000000000206"))
        #expect(product.name == "Surface disinfectant")
        #expect(product.categoryName == "Sterilization")
        #expect(product.categoryId == UUID(uuidString: "00000000-0000-4000-8000-0000000000c7"))
        #expect(product.supplier == "Benco")
        #expect(product.unit == "bottles")
        #expect(product.packUnit == nil && product.packSize == nil)
        #expect(product.minimum == 0 && product.target == 4)
        #expect(product.tracking == .multiUse)
        #expect(product.location == "Sterilization · Cabinet")
        #expect(product.status == .healthy)
        #expect(product.quantity == 3 && product.unopened == 1 && product.openCount == 2)
        #expect(product.missingExpiryQty == 0)
        #expect(payload.usedIn30Days == 3)
        #expect(payload.lastCountedAt == Date(timeIntervalSince1970: 1_790_862_060))
        #expect(payload.toBuyItemId == UUID(uuidString: "e0000000-0000-4000-8000-000000000301"))
        #expect(payload.batches.map(\.lot) == [nil])
        #expect(payload.batches.first?.expiryMonth == CalendarDay(year: 2028, month: 6, day: 1))
        #expect(payload.batches.first?.qty == 1)
        #expect(payload.openItems.map(\.openedByName) == ["Sarah Mitchell", "Michael Reyes"])
        #expect(payload.openItems.first?.openedAt == Date(timeIntervalSince1970: 1_792_152_300))
        #expect(payload.history.map(\.type) == [.adjustment, .adjustment])
        #expect(payload.history.first?.refLabel == "Opened a new bottle")
        #expect(payload.history.first?.reason == nil)
        #expect(payload.history.first?.qtyBefore == 3 && payload.history.first?.qtyAfter == 3)
        #expect(payload.history.first?.byName == "Sarah Mitchell")
    }
}
