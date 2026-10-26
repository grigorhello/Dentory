import Foundation
import Testing
@testable import Dentory

/// `receive_products` decodes straight into `ReceivableProduct` (as the local database answers it for the demo clinic),
/// the cache round-trips it, and the receipt goes to `stock_receive` as one line, referenced as Receive manually.
struct ManualReceiveWireTests {
    private let json = #"""
    [{"id":"d0000000-0000-4000-8000-000000000228","name":"Gauze","category_name":"Surgical","unit":"packs",
      "pack_unit":null,"pack_size":null,"tracking":"countable","quantity":8.00,"unopened":8.00,"open_count":0},
     {"id":"d0000000-0000-4000-8000-000000000217","name":"Root canal sealer","category_name":"Endodontics",
      "unit":"kits","pack_unit":null,"pack_size":null,"tracking":"multi_use","quantity":1.00,"unopened":0.00,
      "open_count":1},
     {"id":"d0000000-0000-4000-8000-000000000201","name":"Septocaine 4% 1:100,000","category_name":"Anesthetic",
      "unit":"cartridges","pack_unit":"box","pack_size":50,"tracking":"countable","quantity":54.00,
      "unopened":54.00,"open_count":0}]
    """#

    private func object(_ params: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder.supabase.encode(params)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func theProductsDecodeWithTheirPackAndStock() throws {
        let products = try JSONDecoder.supabase.decode([ReceivableProduct].self, from: Data(json.utf8))
        #expect(products.map(\.name) == ["Gauze", "Root canal sealer", "Septocaine 4% 1:100,000"])
        let septocaine = products[2]
        #expect(septocaine.packUnit == "box" && septocaine.packSize == 50)
        #expect(septocaine.categoryName == "Anesthetic")
        #expect(septocaine.quantity == 54)
        let sealer = products[1]
        #expect(sealer.tracking == .multiUse)
        #expect(sealer.unopened == 0 && sealer.openCount == 1 && sealer.quantity == 1)
        #expect(products[0].packUnit == nil && products[0].packSize == nil)
    }

    @Test func theCacheKeepsTheProductsAsTheServerSentThem() throws {
        let products = try JSONDecoder.supabase.decode([ReceivableProduct].self, from: Data(json.utf8))
        let cache = InMemoryResponseCache()
        let key = CacheKey(method: "ManualReceiveWireTests", clinicID: Session.demo.clinicID)
        cache.store(products, for: key)
        #expect(cache.load([ReceivableProduct].self, for: key) == products)
    }

    @Test func theReceiptIsOneLineInCountedUnitsReferencedAsReceiveManually() throws {
        let productID = try #require(UUID(uuidString: "d0000000-0000-4000-8000-000000000201"))
        let json = try object(StockReceiveParams(ManualReceipt(
            clinicID: Session.demo.clinicID, productID: productID, quantity: 250,
            unitCost: Decimal(996) / 1000, lot: "L-77",
            expiryMonth: CalendarDay(year: 2027, month: 3, day: 1)
        )))
        #expect(Set(json.keys) == ["p_clinic_id", "p_lines", "p_ref_type", "p_ref_label"])
        #expect((json["p_clinic_id"] as? String)?.lowercased() == Session.demo.clinicID.uuidString.lowercased())
        #expect(json["p_ref_type"] as? String == "manual")
        #expect(json["p_ref_label"] as? String == "Receive manually")
        let lines = try #require(json["p_lines"] as? [[String: Any]])
        #expect(lines.count == 1)
        let line = try #require(lines.first)
        #expect(Set(line.keys) == ["product_id", "qty", "unit_cost", "lot", "expiry_month"])
        #expect((line["product_id"] as? String)?.lowercased() == productID.uuidString.lowercased())
        #expect((line["qty"] as? NSNumber)?.intValue == 250)
        #expect((line["unit_cost"] as? NSNumber)?.doubleValue == 0.996)
        #expect(line["lot"] as? String == "L-77")
        #expect(line["expiry_month"] as? String == "2027-03-01")
    }

    /// `stock_receive` reads a missing key as null: no cost keeps the last unit cost, no expiry leaves it undated.
    @Test func aReceiptWithoutCostLotOrExpiryLeavesThemOut() throws {
        let json = try object(StockReceiveParams(ManualReceipt(
            clinicID: Session.demo.clinicID, productID: UUID(), quantity: 4, unitCost: nil, lot: nil, expiryMonth: nil
        )))
        let line = try #require((json["p_lines"] as? [[String: Any]])?.first)
        #expect(Set(line.keys) == ["product_id", "qty"])
    }
}
