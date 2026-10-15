import Testing
@testable import MediSave

struct AppTabTests {
    @Test func tabsAreInTabBarOrder() {
        #expect(AppTab.allCases.map(\.title) == ["Home", "Inventory", "Procedures", "To buy"])
    }

    @Test func accessibilityIdentifiersAreUnique() {
        let ids = AppTab.allCases.map(\.accessibilityIdentifier)
        #expect(Set(ids).count == ids.count)
    }
}
