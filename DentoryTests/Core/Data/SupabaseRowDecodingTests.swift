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
}
