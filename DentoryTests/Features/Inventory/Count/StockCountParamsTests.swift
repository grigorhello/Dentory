import Foundation
import Testing
@testable import Dentory

struct StockCountParamsTests {
    @Test func theParametersReadAsTheFunctionExpectsThem() throws {
        let productID = ProductSummary.demo[0].id
        let params = StockCountParams(
            pClinicId: Session.demo.clinicID,
            pCounts: [StockCountParams.Line(productId: productID, counted: 52)]
        )
        let data = try JSONEncoder.supabase.encode(params)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_clinic_id", "p_counts"], "The coordinator adds p_idempotency_key")
        #expect((object["p_clinic_id"] as? String)?.lowercased() == Session.demo.clinicID.uuidString.lowercased())
        let lines = try #require(object["p_counts"] as? [[String: Any]])
        #expect(lines.count == 1)
        #expect((lines[0]["product_id"] as? String)?.lowercased() == productID.uuidString.lowercased())
        #expect((lines[0]["counted"] as? NSNumber)?.intValue == 52)
    }
}
