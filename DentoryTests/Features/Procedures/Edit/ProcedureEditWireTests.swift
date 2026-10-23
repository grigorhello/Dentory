import Foundation
import Testing
@testable import Dentory

/// `procedure_template_save` gets its parameters under the names the function reads, and its answer decodes.
struct ProcedureEditWireTests {
    @Test func aNewTemplateSendsItsIdAsNull() throws {
        let gauze = DemoSupplies.extraProducts[7].id
        let request = ProcedureTemplateSaveRequest(
            clinicID: Session.demo.clinicID, templateID: nil, name: "Extraction",
            lines: [.init(productID: gauze, defaultQuantity: 4)]
        )
        let data = try JSONEncoder.supabase.encode(ProcedureTemplateSaveParams(request))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_clinic_id", "p_template_id", "p_name", "p_items"])
        #expect(object["p_template_id"] is NSNull)
        #expect(object["p_name"] as? String == "Extraction")
        let items = try #require(object["p_items"] as? [[String: Any]])
        #expect((items.first?["product_id"] as? String)?.lowercased() == gauze.uuidString.lowercased())
        #expect((items.first?["default_qty"] as? NSNumber)?.intValue == 4)
    }

    @Test func anExistingTemplateSendsItsId() throws {
        let rootCanal = ProcedureTemplateSummary.demo[0].id
        let request = ProcedureTemplateSaveRequest(
            clinicID: Session.demo.clinicID, templateID: rootCanal, name: "Root canal", lines: []
        )
        let data = try JSONEncoder.supabase.encode(ProcedureTemplateSaveParams(request))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((object["p_template_id"] as? String)?.lowercased() == rootCanal.uuidString.lowercased())
        #expect((object["p_items"] as? [Any])?.isEmpty == true)
    }

    @Test func theSavedTemplateDecodes() throws {
        let json = #"{"id":"d0000000-0000-4000-8000-000000000301","name":"Untitled procedure","item_count":3}"#
        let saved = try JSONDecoder.supabase.decode(SavedProcedureTemplate.self, from: Data(json.utf8))
        #expect(saved == SavedProcedureTemplate(
            id: ProcedureTemplateSummary.demo[0].id, name: "Untitled procedure", itemCount: 3
        ))
    }
}
