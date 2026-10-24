import Foundation
import Testing
@testable import Dentory

/// `activity_history` names its columns after `ActivityHistoryEntry`, so its rows decode straight into it with the
/// client's decoder; the parameters go out with explicit nulls.
struct ActivityHistoryWireTests {
    @Test func rowsDecodeIntoTheEntry() throws {
        let json = #"""
        [{"id":"00000000-0000-4000-8000-000000013431","at":"2026-10-01T19:14:00.123456+00:00","type":"procedure",
          "subject":"Root canal","product_id":null,"delta":-4.00,"qty_before":null,"qty_after":null,
          "ref_type":"procedure_event","ref_label":"Root canal","reason":null,"note":null,"is_edit":false,
          "by_name":"Sarah Mitchell"},
         {"id":"00000000-0000-4000-8000-000000013449","at":"2026-10-01T20:22:00+00:00","type":"count",
          "subject":"Septocaine","product_id":"00000000-0000-4000-8000-000000013421","delta":-2.00,"qty_before":43.00,
          "qty_after":41.00,"ref_type":"count_session","ref_label":"Physical count","reason":"Physical count",
          "note":null,"is_edit":false,"by_name":""}]
        """#
        let rows = try JSONDecoder.supabase.decode([ActivityHistoryEntry].self, from: Data(json.utf8))
        #expect(rows.first?.type == .procedure)
        #expect(rows.first?.productID == nil)
        #expect(rows.first?.delta == -4)
        #expect(rows.first?.refType == "procedure_event")
        #expect(rows.last?.productID == UUID(uuidString: "00000000-0000-4000-8000-000000013421"))
        #expect(rows.last?.qtyBefore == 43)
        #expect(rows.last?.qtyAfter == 41)
        #expect(rows.last?.byName == "")
        // The cache keeps every field; its dates keep whole seconds, which is all a row shows (pages go by id).
        let encoded = try JSONEncoder.supabase.encode(rows)
        let cached = try JSONDecoder.supabase.decode([ActivityHistoryEntry].self, from: encoded)
        #expect(cached.map(\.id) == rows.map(\.id))
        #expect(cached.map(\.subject) == rows.map(\.subject))
        #expect(abs((cached.first?.at ?? .distantPast).timeIntervalSince(rows.first?.at ?? .distantFuture)) < 1)
    }

    @Test func theFirstPageSendsEveryParameter() throws {
        let params = ActivityHistoryParams(
            pClinicId: Session.demo.clinicID, pFilter: nil, pProductId: nil, pAfterId: nil, pLimit: 50
        )
        let data = try JSONEncoder.supabase.encode(params)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_clinic_id", "p_filter", "p_product_id", "p_after_id", "p_limit"])
        #expect(object["p_filter"] is NSNull)
        #expect(object["p_after_id"] is NSNull)
        #expect(ActivityHistoryFilter.counts.parameter == "counts")
        #expect(ActivityHistoryFilter.all.parameter == nil)
    }
}
