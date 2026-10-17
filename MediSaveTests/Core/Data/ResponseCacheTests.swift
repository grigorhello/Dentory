import Foundation
import Testing
@testable import MediSave

struct ResponseCacheTests {
    private nonisolated struct Row: Codable, Equatable, Sendable {
        let name: String
        let quantity: Decimal
        let expiryMonth: CalendarDay?
    }

    @Test func storesAndLoadsByMethodAndClinic() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ms108-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileResponseCache(directory: directory)
        let key = CacheKey(method: "InventoryRepository.products", clinicID: Session.demo.clinicID)
        let rows = [Row(name: "Septocaine 4%", quantity: 54, expiryMonth: CalendarDay(year: 2026, month: 12, day: 1))]

        #expect(cache.load([Row].self, for: key) == nil)
        cache.store(rows, for: key)
        #expect(cache.load([Row].self, for: key) == rows)
        #expect(cache.load([Row].self, for: CacheKey(method: "other", clinicID: Session.demo.clinicID)) == nil)
        #expect(cache.load([Row].self, for: CacheKey(method: key.method, clinicID: UUID())) == nil)

        cache.removeAll()
        #expect(cache.load([Row].self, for: key) == nil)
    }

    @Test func keysMakeSafeFileNames() {
        let key = CacheKey(method: "Inventory/products?filter=low", clinicID: Session.demo.clinicID)
        let clinic = Session.demo.clinicID.uuidString.lowercased()
        #expect(key.fileName == "\(clinic)-Inventory-products-filter-low.json")
    }

    @Test func theInMemoryCacheBehavesTheSame() {
        let cache = InMemoryResponseCache()
        let key = CacheKey(method: "m", clinicID: UUID())
        cache.store([Row(name: "a", quantity: 1, expiryMonth: nil)], for: key)
        #expect(cache.load([Row].self, for: key)?.count == 1)
    }
}
