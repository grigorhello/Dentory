import Testing
@testable import MediSave

@MainActor
struct AppRouterTests {
    private enum Route: Hashable { case product(Int), batch(Int) }

    @Test func startsOnHomeWithEmptyPaths() {
        let router = AppRouter()
        #expect(router.selectedTab == .home)
        for tab in AppTab.allCases {
            #expect(router.path(for: tab).isEmpty)
        }
        #expect(router.toBuyCount == 0)
    }

    @Test func eachTabKeepsItsOwnPath() {
        let router = AppRouter()
        router.push(Route.product(1), on: .inventory)
        router.push(Route.batch(2), on: .inventory)
        router.push(Route.product(3), on: .procedures)
        #expect(router.path(for: .inventory).count == 2)
        #expect(router.path(for: .procedures).count == 1)
        #expect(router.path(for: .home).isEmpty)
    }

    @Test func pushAndPopUseTheSelectedTabByDefault() {
        let router = AppRouter(selectedTab: .toBuy)
        router.push(Route.product(1))
        #expect(router.path(for: .toBuy).count == 1)
        router.pop()
        #expect(router.path(for: .toBuy).isEmpty)
        router.pop()
        #expect(router.path(for: .toBuy).isEmpty)
    }

    @Test func selectingAnotherTabKeepsThePushedScreens() {
        let router = AppRouter()
        router.push(Route.product(1), on: .inventory)
        router.select(.inventory)
        #expect(router.selectedTab == .inventory)
        #expect(router.path(for: .inventory).count == 1)
        router.select(.home)
        #expect(router.path(for: .inventory).count == 1)
    }

    @Test func reselectingTheCurrentTabPopsToRoot() {
        let router = AppRouter(selectedTab: .inventory)
        router.push(Route.product(1))
        router.push(Route.batch(2))
        router.select(.inventory)
        #expect(router.selectedTab == .inventory)
        #expect(router.path(for: .inventory).isEmpty)
    }

    @Test func pathBindingWritesThroughToTheRouter() {
        let router = AppRouter()
        let binding = router.pathBinding(for: .home)
        binding.wrappedValue.append(Route.product(9))
        #expect(router.path(for: .home).count == 1)
    }
}
