import Foundation
import Testing
@testable import Dentory

/// `procedure_templates_list` and `procedure_history` name their columns after the domain types, so their
/// rows decode straight into them with the client's decoder; the history's cursor goes out as explicit nulls.
struct ProcedureRowsDecodingTests {
    @Test func templateRowsDecodeIntoTheSummary() throws {
        let json = #"""
        [{"id":"d0000000-0000-4000-8000-000000000301","name":"Root canal","item_count":12,
          "not_available_count":1,"run_out_count":1}]
        """#
        let rows = try JSONDecoder.supabase.decode([ProcedureTemplateSummary].self, from: Data(json.utf8))
        #expect(rows == [ProcedureTemplateSummary.demo[0]])
    }

    @Test func historyRowsDecodeWithAndWithoutACancellation() throws {
        let json = #"""
        [{"id":"00000000-0000-4000-8000-0000000000e1","name":"Root canal","started_at":"2026-10-01T19:14:00+00:00",
          "started_by_name":"Sarah Mitchell","item_count":12,"cancelled_at":null},
         {"id":"00000000-0000-4000-8000-0000000000e9","name":"Crown","started_at":"2026-10-01T15:00:00.123456+00:00",
          "started_by_name":"","item_count":10,"cancelled_at":"2026-10-01T16:00:00+00:00"}]
        """#
        let rows = try JSONDecoder.supabase.decode([ProcedureEventSummary].self, from: Data(json.utf8))
        #expect(rows.first == ProcedureEventSummary.demo[0])
        #expect(rows.last?.cancelledAt != nil)
        #expect(rows.last?.startedByName == "")
    }

    @Test func theFirstPageSendsTheCursorAsNulls() throws {
        let params = ProcedureHistoryParams(
            pClinicId: Session.demo.clinicID, pBeforeAt: nil, pBeforeId: nil, pLimit: 30
        )
        let object = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder.supabase.encode(params)) as? [String: Any]
        )
        #expect(Set(object.keys) == ["p_clinic_id", "p_before_at", "p_before_id", "p_limit"])
        #expect(object["p_before_at"] is NSNull)
        #expect(object["p_before_id"] is NSNull)
        #expect((object["p_limit"] as? NSNumber)?.intValue == 30)
    }
}
