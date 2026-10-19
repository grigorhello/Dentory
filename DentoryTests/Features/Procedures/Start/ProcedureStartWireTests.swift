import Foundation
import Testing
@testable import Dentory

/// `procedure_template_detail` decodes straight into the domain types; `stock_procedure_start` gets its parameters
/// under the names the function reads.
struct ProcedureStartWireTests {
    @Test func theTemplateDecodesWithItsSupplies() throws {
        let json = #"""
        {"id":"d0000000-0000-4000-8000-000000000301","name":"Root canal","items":[
          {"id":"00000000-0000-4000-8000-0000000000d1","name":"Septocaine 4% 1:100,000","unit":"cartridges",
           "tracking":"countable","default_qty":2.00,"quantity":54.00,"unopened":54.00,"open_count":0},
          {"id":"00000000-0000-4000-8000-0000000000d6","name":"Surface disinfectant","unit":"bottles",
           "tracking":"multi_use","default_qty":0.00,"quantity":3.00,"unopened":1.00,"open_count":2}]}
        """#
        let detail = try JSONDecoder.supabase.decode(ProcedureTemplateDetail.self, from: Data(json.utf8))
        #expect(detail.name == "Root canal")
        #expect(detail.items.map(\.tracking) == [.countable, .multiUse])
        #expect(detail.items.first?.defaultQty == 2)
        #expect(detail.items.last?.openCount == 2)
    }

    @Test func theStartParametersReadAsTheFunctionExpectsThem() throws {
        let septocaine = ProductSummary.demo[0].id
        let disinfectant = ProductSummary.demo[5].id
        let request = ProcedureStartRequest(
            clinicID: Session.demo.clinicID, templateID: ProcedureTemplateSummary.demo[0].id, name: "Root canal",
            lines: [
                ProcedureStartLine(productID: septocaine, quantity: 3),
                ProcedureStartLine(productID: disinfectant, quantity: 0)
            ],
            takeNew: [disinfectant]
        )
        let data = try JSONEncoder.supabase.encode(ProcedureStartParams(request))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_clinic_id", "p_template_id", "p_name", "p_items", "p_take_new"])
        #expect(object["p_name"] as? String == "Root canal")
        let items = try #require(object["p_items"] as? [[String: Any]])
        #expect((items.first?["product_id"] as? String)?.lowercased() == septocaine.uuidString.lowercased())
        #expect((items.first?["qty"] as? NSNumber)?.intValue == 3)
        let takeNew = try #require(object["p_take_new"] as? [String])
        #expect(takeNew.map { $0.lowercased() } == [disinfectant.uuidString.lowercased()])
    }
}
