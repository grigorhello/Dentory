import Foundation
import Testing
@testable import Dentory

/// `receive_overview` decodes straight into `ReceiveOverview` (as the local database answers it for the demo clinic, a
/// reading that failed with the time it failed), and the cache round-trips it.
struct ReceiveWireTests {
    private let json = #"""
    {"invoices":[
      {"id":"d0000000-0000-4000-8000-000000000401","status":"ready","supplier":"Patterson",
       "created_at":"2026-10-02T12:55:00+00:00","failed_at":null},
      {"id":"d0000000-0000-4000-8000-000000000402","status":"reading","supplier":null,
       "created_at":"2026-10-02T13:40:12+00:00","failed_at":null},
      {"id":"d0000000-0000-4000-8000-000000000403","status":"failed","supplier":null,
       "created_at":"2026-10-02T13:41:05+00:00","failed_at":"2026-10-02T13:41:35+00:00"}],
     "waiting":[
      {"id":"3f671390-a260-4ccc-9e5c-a988070f0d1c","qty":60.00,"name":"Needle 27g short","unit":"needles",
       "supplier":"Patterson","ordered_at":"2026-10-01T20:40:00+00:00",
       "product_id":"d0000000-0000-4000-8000-000000000221"},
      {"id":"584f36f8-c07f-4e8b-9d80-5445a9c60b6b","qty":1,"name":"Root canal sealer","unit":"kits",
       "supplier":null,"ordered_at":"2026-10-01T20:40:00+00:00",
       "product_id":"d0000000-0000-4000-8000-000000000217"}]}
    """#

    @Test func theOverviewDecodesWithItsInvoicesAndLines() throws {
        let overview = try JSONDecoder.supabase.decode(ReceiveOverview.self, from: Data(json.utf8))
        #expect(overview.invoices.map(\.status) == [.ready, .reading, .failed])
        #expect(overview.invoices.map(\.supplier) == ["Patterson", nil, nil])
        #expect(overview.invoices[0].createdAt == Date(timeIntervalSince1970: 1_790_945_700))
        #expect(overview.invoices.map(\.failedAt) == [nil, nil, Date(timeIntervalSince1970: 1_790_948_495)])
        #expect(overview.waiting.map(\.name) == ["Needle 27g short", "Root canal sealer"])
        #expect(overview.waiting[0].quantity == 60)
        #expect(overview.waiting[0].unit == "needles")
        #expect(overview.waiting[0].productID == UUID(uuidString: "d0000000-0000-4000-8000-000000000221"))
        #expect(overview.waiting[1].supplier == nil)
    }

    @Test func theCacheKeepsTheOverviewAsTheServerSentIt() throws {
        let overview = try JSONDecoder.supabase.decode(ReceiveOverview.self, from: Data(json.utf8))
        let cache = InMemoryResponseCache()
        let key = CacheKey(method: "ReceiveWireTests", clinicID: Session.demo.clinicID)
        cache.store(overview, for: key)
        #expect(cache.load(ReceiveOverview.self, for: key) == overview)
    }
}
