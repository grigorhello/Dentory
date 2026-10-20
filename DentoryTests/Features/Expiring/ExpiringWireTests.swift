import Foundation
import Testing
@testable import Dentory

/// `expiring_batches` decodes straight into `ExpiringList`, the cache round-trips it, and `stock_dispose` gets its
/// parameters under the names the function reads.
struct ExpiringWireTests {
    private let json = #"""
    {"window":90,"batches":[
      {"id":"00000000-0000-4000-8000-000000000601","product_id":"00000000-0000-4000-8000-0000000000d4",
       "name":"Bonding agent","unit":"bottles","tracking":"multi_use","qty":1.00,"lot":"BA7",
       "expiry_month":"2026-11-01","value":82.00},
      {"id":"00000000-0000-4000-8000-000000000603","product_id":"00000000-0000-4000-8000-0000000000d8",
       "name":"Gutta percha F2","unit":"packs","tracking":"countable","qty":2,"lot":null,
       "expiry_month":"2026-12-01","value":0}]}
    """#

    @Test func theListDecodesWithItsBatches() throws {
        let list = try JSONDecoder.supabase.decode(ExpiringList.self, from: Data(json.utf8))
        #expect(list.window == 90)
        #expect(list.batches.map(\.name) == ["Bonding agent", "Gutta percha F2"])
        #expect(list.batches.first == ExpiringBatch.demo[0])
        #expect(list.batches.last?.lot == nil)
        #expect(list.batches.last?.tracking == .countable)
    }

    @Test func theCacheKeepsTheListAsTheServerSentIt() throws {
        let list = try JSONDecoder.supabase.decode(ExpiringList.self, from: Data(json.utf8))
        let cache = InMemoryResponseCache()
        let key = CacheKey(method: "ExpiringWireTests", clinicID: Session.demo.clinicID)
        cache.store(list, for: key)
        #expect(cache.load(ExpiringList.self, for: key) == list)
    }

    @Test func disposeSendsTheBatchAndTheQuantity() throws {
        let batch = ExpiringBatch.demo[1]
        let data = try JSONEncoder.supabase.encode(StockDisposeParams(pBatchId: batch.id, pQty: 34))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["p_batch_id", "p_qty"])
        #expect((object["p_batch_id"] as? String)?.lowercased() == batch.id.uuidString.lowercased())
        #expect((object["p_qty"] as? NSNumber)?.intValue == 34)
    }
}
