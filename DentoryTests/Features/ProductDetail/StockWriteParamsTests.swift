import Foundation
import Testing
@testable import Dentory

/// The stock functions are matched by their full parameter list, so a missing value must go as null.
struct StockWriteParamsTests {
    private func object(_ params: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder.supabase.encode(params)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func aNewBatchSendsNullsForTheBatchAndTheLot() throws {
        let productID = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000d8"))
        let params = BatchUpsertParams(
            pProductId: productID, pBatchId: nil, pExpiryMonth: CalendarDay(year: 2026, month: 12, day: 1),
            pQty: 7, pLot: nil
        )
        let json = try object(params)
        #expect(Set(json.keys) == ["p_product_id", "p_batch_id", "p_expiry_month", "p_qty", "p_lot"])
        #expect(json["p_batch_id"] is NSNull && json["p_lot"] is NSNull)
        #expect(json["p_expiry_month"] as? String == "2026-12-01")
        #expect((json["p_qty"] as? NSNumber)?.intValue == 7)
        #expect((json["p_product_id"] as? String)?.lowercased() == productID.uuidString.lowercased())
    }

    @Test func anEditedBatchSendsItsIDAndLot() throws {
        let batchID = UUID()
        let json = try object(BatchUpsertParams(
            pProductId: UUID(), pBatchId: batchID, pExpiryMonth: CalendarDay(year: 2027, month: 3, day: 1),
            pQty: Decimal(string: "2.5") ?? 0, pLot: "A112"
        ))
        #expect((json["p_batch_id"] as? String)?.lowercased() == batchID.uuidString.lowercased())
        #expect(json["p_lot"] as? String == "A112")
        #expect((json["p_qty"] as? NSNumber)?.doubleValue == 2.5)
    }
}
