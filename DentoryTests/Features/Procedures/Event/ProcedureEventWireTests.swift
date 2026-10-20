import Foundation
import Testing
@testable import Dentory

/// `procedure_event_detail` decodes straight into the domain type; `stock_procedure_edit` and
/// `stock_procedure_cancel` get their parameters under the names the functions read.
struct ProcedureEventWireTests {
    @Test func theRecordDecodesWithItsSupplies() throws {
        let json = #"""
        {"id":"00000000-0000-4000-8000-0000000000e1","template_id":"d0000000-0000-4000-8000-000000000301",
         "name":"Root canal","started_at":"2026-10-01T19:14:00+00:00","started_by_name":"Sarah Mitchell",
         "cancelled_at":null,"cancelled_by_name":"","cancel_note":null,"items":[
          {"id":"00000000-0000-4000-8000-0000000000d1","name":"Septocaine 4% 1:100,000","unit":"cartridges",
           "tracking":"countable","qty":2.00,"taken_new":false,"quantity":54.00,"unopened":54.00,"open_count":0},
          {"id":"00000000-0000-4000-8000-0000000000d6","name":"Surface disinfectant","unit":"bottles",
           "tracking":"multi_use","qty":0,"taken_new":true,"quantity":3.00,"unopened":1.00,"open_count":2}]}
        """#
        let detail = try JSONDecoder.supabase.decode(ProcedureEventDetail.self, from: Data(json.utf8))
        #expect(detail.templateID == ProcedureTemplateSummary.demo[0].id)
        #expect(detail.startedByName == "Sarah Mitchell")
        #expect(detail.startedAt == Date(timeIntervalSince1970: 1_790_882_040))
        #expect(detail.isCancelled == false)
        #expect(detail.items.map(\.tracking) == [.countable, .multiUse])
        #expect(detail.items.last?.takenNew == true)
        #expect(detail.items.last?.openCount == 2)
        #expect(detail.itemsDeducted == 3, "Two cartridges and one bottle opened")
    }

    @Test func aCancelledRecordDecodesWithWhoAndWhy() throws {
        let json = #"""
        {"id":"00000000-0000-4000-8000-0000000000e1","template_id":null,"name":"Root canal",
         "started_at":"2026-10-01T19:14:00+00:00","started_by_name":"Sarah Mitchell",
         "cancelled_at":"2026-10-02T13:41:00+00:00","cancelled_by_name":"Michael Reyes",
         "cancel_note":"Logged by mistake","items":[]}
        """#
        let detail = try JSONDecoder.supabase.decode(ProcedureEventDetail.self, from: Data(json.utf8))
        #expect(detail.templateID == nil)
        #expect(detail.isCancelled)
        #expect(detail.cancelledByName == "Michael Reyes")
        #expect(detail.cancelNote == "Logged by mistake")
    }

    @Test func theEditParametersReadAsTheFunctionExpectsThem() throws {
        let septocaine = ProductSummary.demo[0].id
        let disinfectant = ProductSummary.demo[5].id
        let edit = ProcedureUsageEdit(
            eventID: ProcedureEventSummary.demo[0].id,
            lines: [
                ProcedureStartLine(productID: septocaine, quantity: 3),
                ProcedureStartLine(productID: disinfectant, quantity: 0)
            ],
            takeNew: [disinfectant]
        )
        let data = try JSONEncoder.supabase.encode(ProcedureUsageEditParams(edit))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_event_id", "p_items", "p_take_new"])
        #expect((object["p_event_id"] as? String)?.lowercased() == edit.eventID.uuidString.lowercased())
        let items = try #require(object["p_items"] as? [[String: Any]])
        #expect((items.first?["product_id"] as? String)?.lowercased() == septocaine.uuidString.lowercased())
        #expect((items.first?["qty"] as? NSNumber)?.intValue == 3)
        let takeNew = try #require(object["p_take_new"] as? [String])
        #expect(takeNew.map { $0.lowercased() } == [disinfectant.uuidString.lowercased()])
    }

    @Test func theCancelParametersReadAsTheFunctionExpectsThem() throws {
        let eventID = ProcedureEventSummary.demo[0].id
        let data = try JSONEncoder.supabase.encode(ProcedureCancelParams(pEventId: eventID, pNote: "Logged by mistake"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_event_id", "p_note"])
        #expect((object["p_event_id"] as? String)?.lowercased() == eventID.uuidString.lowercased())
        #expect(object["p_note"] as? String == "Logged by mistake")
    }
}
