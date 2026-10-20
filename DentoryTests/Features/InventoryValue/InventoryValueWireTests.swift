import Foundation
import Testing
@testable import Dentory

/// `inventory_value` answers one JSON object; it decodes straight into `InventoryValue` with the client's decoder
/// and survives the cache's encoder.
struct InventoryValueWireTests {
    private let json = #"""
    {"total": 388.60, "at_risk_90": 61.20, "used_30": 55.60, "received_30": 36.00, "uncosted_count": 1,
     "categories": [
       {"category_id": "00000000-0000-4000-8000-000000013522", "name": "Restorative", "value": 166.00,
        "product_count": 3},
       {"category_id": null, "name": null, "value": 78.40, "product_count": 1}],
     "top_products": [
       {"product_id": "00000000-0000-4000-8000-000000013531", "name": "Septocaine", "unit": "cartridges",
        "quantity": 54.00, "unit_cost": 1.8000, "value": 97.20}]}
    """#

    @Test func theAnswerDecodesIntoTheValue() throws {
        let value = try JSONDecoder.supabase.decode(InventoryValue.self, from: Data(json.utf8))
        #expect(value.total == Decimal(38_860) / 100)
        #expect(value.atRisk90 == Decimal(6_120) / 100)
        #expect(value.used30 == Decimal(5_560) / 100)
        #expect(value.received30 == 36)
        #expect(value.uncostedCount == 1)
        #expect(value.categories.map(\.name) == ["Restorative", nil])
        #expect(value.categories.first?.categoryID == UUID(uuidString: "00000000-0000-4000-8000-000000013522"))
        #expect(value.categories.last?.categoryID == nil)
        #expect(value.categories.map(\.productCount) == [3, 1])
        let septocaine = try #require(value.topProducts.first)
        #expect(septocaine.productID == UUID(uuidString: "00000000-0000-4000-8000-000000013531"))
        #expect(septocaine.unit == "cartridges")
        #expect(septocaine.quantity == 54)
        #expect(septocaine.unitCost == Decimal(180) / 100)
        #expect(septocaine.value == Decimal(9_720) / 100)
    }

    @Test func theCachedAnswerReadsBackTheSame() throws {
        let value = try JSONDecoder.supabase.decode(InventoryValue.self, from: Data(json.utf8))
        let cached = try JSONDecoder.supabase.decode(InventoryValue.self, from: JSONEncoder.supabase.encode(value))
        #expect(cached == value)
        let demoJSON = try JSONEncoder.supabase.encode(InventoryValue.demo)
        let demo = try JSONDecoder.supabase.decode(InventoryValue.self, from: demoJSON)
        #expect(demo == .demo)
    }
}
