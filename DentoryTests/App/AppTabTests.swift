import Testing
@testable import Dentory

struct AppTabTests {
    @Test func tabsAreInTabBarOrder() {
        #expect(AppTab.allCases.map(\.title) == ["Home", "Inventory", "Procedures", "To buy"])
    }

    @Test func tabsUseTheLucideIconsOfTheFrame() {
        #expect(AppTab.allCases.map(\.icon) == [.layoutGrid, .package, .clipboardCheck, .clipboardList])
    }

    @Test func accessibilityIdentifiersAreUnique() {
        let ids = AppTab.allCases.map(\.accessibilityIdentifier)
        #expect(Set(ids).count == ids.count)
    }
}
