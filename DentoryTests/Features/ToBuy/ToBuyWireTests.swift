import Foundation
import Testing
@testable import Dentory

/// `to_buy_list` rows decode into `ToBuyItem`, `to_buy_add` answers decode, and `to_buy_mark_ordered` gets its
/// parameters under the names the function reads.
struct ToBuyWireTests {
    @Test func aListRowDecodes() throws {
        let json = #"""
        [{"id":"3cc7fd08-571e-4911-8464-2fd2abb1c646","product_id":"d0000000-0000-4000-8000-000000000202",
          "name":"Endo file kit #15-40","unit":"kits","supplier":"Patterson","quantity":1.00,"target":5.00,
          "qty":4.00,"qty_edited":false,"source":"auto","status":"to_buy","created_at":"2026-08-05T13:00:00+00:00",
          "ordered_at":null,"received_at":null},
         {"id":"114cc668-633d-40f4-9e3a-23c93abb1924","product_id":"d0000000-0000-4000-8000-000000000210",
          "name":"Alginate impression","unit":"bags","supplier":null,"quantity":4.00,"target":6.00,"qty":2.00,
          "qty_edited":true,"source":"manual","status":"received","created_at":"2026-10-09T20:30:00.123+00:00",
          "ordered_at":"2026-10-10T14:00:00+00:00","received_at":"2026-10-13T15:40:00+00:00"}]
        """#
        let items = try JSONDecoder.supabase.decode([ToBuyItem].self, from: Data(json.utf8))
        let endo = try #require(items.first)
        #expect(endo.productID.uuidString.lowercased() == "d0000000-0000-4000-8000-000000000202")
        #expect(endo.buyQuantity == 4)
        #expect(endo.quantity == 1 && endo.target == 5)
        #expect(endo.status == .toBuy && endo.source == .auto)
        #expect(endo.orderedAt == nil)
        let alginate = try #require(items.last)
        #expect(alginate.supplier == nil)
        #expect(alginate.status == .received && alginate.source == .manual)
        #expect(alginate.receivedAt != nil)
    }

    @Test func anAddedLineDecodes() throws {
        let json = #"{"id":"d0000000-0000-4000-8000-000000000301","qty":8.00,"created":false}"#
        let added = try JSONDecoder.supabase.decode(AddedToBuy.self, from: Data(json.utf8))
        #expect(added.qty == 8)
        #expect(added.created == false, "Already on the list: no Undo")
    }

    @Test func markOrderedSendsTheClinicAndTheLines() throws {
        let lines = [UUID(), UUID()]
        let params = ToBuyMarkOrderedParams(pClinicId: Session.demo.clinicID, pItemIds: lines)
        let data = try JSONEncoder.supabase.encode(params)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_clinic_id", "p_item_ids"])
        let ids = try #require(object["p_item_ids"] as? [String])
        #expect(ids.map { $0.lowercased() } == lines.map { $0.uuidString.lowercased() })
    }
}
