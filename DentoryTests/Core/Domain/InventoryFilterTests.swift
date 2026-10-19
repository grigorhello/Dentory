import Testing
@testable import Dentory

struct InventoryFilterTests {
    @Test func allTakesEveryStatus() {
        for status in ProductStatus.allCases {
            #expect(InventoryFilter.all.includes(status))
        }
    }

    @Test func lowIncludesOutOfStock() {
        #expect(InventoryFilter.low.includes(.low))
        #expect(InventoryFilter.low.includes(.outOfStock))
        #expect(!InventoryFilter.low.includes(.expiring))
        #expect(!InventoryFilter.low.includes(.healthy))
    }

    @Test func theOtherChipsMatchTheirStatusOnly() {
        #expect(InventoryFilter.expiring.includes(.expiring))
        #expect(!InventoryFilter.expiring.includes(.missingExpiry))
        #expect(InventoryFilter.missingExpiry.includes(.missingExpiry))
        #expect(!InventoryFilter.missingExpiry.includes(.low))
        #expect(InventoryFilter.healthy.includes(.healthy))
        #expect(!InventoryFilter.healthy.includes(.outOfStock))
    }

    @Test func chipsAreInTheFrameOrder() {
        #expect(InventoryFilter.allCases.map(\.rawValue) == ["All", "Low", "Expiring", "Missing expiry", "Healthy"])
    }

    @Test func statusesSortOutOfStockFirstAndHealthyLast() {
        #expect(ProductStatus.outOfStock.sortRank < ProductStatus.low.sortRank)
        #expect(ProductStatus.low.sortRank < ProductStatus.expiring.sortRank)
        #expect(ProductStatus.expiring.sortRank < ProductStatus.missingExpiry.sortRank)
        #expect(ProductStatus.missingExpiry.sortRank < ProductStatus.healthy.sortRank)
    }
}
