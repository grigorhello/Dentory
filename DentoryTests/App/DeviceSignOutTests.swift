import Foundation
import Testing
@testable import Dentory

/// Sign out leaves nothing of the clinic on the device (MS-137 acceptance): the cached answers and the queued writes
/// are gone, the session has ended, and the router starts the next person on Home.
@MainActor
struct DeviceSignOutTests {
    @Test func signingOutClearsTheDeviceAndEndsTheSession() async {
        let cache = InMemoryResponseCache()
        let key = CacheKey(method: "HomeRepository.summary", clinicID: Session.demo.clinicID)
        cache.store(HomeSummary.demo, for: key)
        let queue = PendingWriteQueue(store: InMemoryPendingWriteStore())
        _ = queue.enqueue(function: "stock_adjust", params: [:], key: UUID(), at: Session.demoNow)
        let store = SessionStore(auth: PreviewAuthService(session: .demo), state: .signedIn(.demo))
        let signOut = DeviceSignOut(sessionStore: store, cache: cache, writes: queue)
        #expect(signOut.unsyncedChangeCount == 1)

        await signOut.signOut()

        #expect(cache.load(HomeSummary.self, for: key) == nil, "Cached clinic data is removed")
        #expect(queue.isEmpty, "Writes made offline are not sent under the next account")
        #expect(signOut.unsyncedChangeCount == 0)
        #expect(store.state == .signedOut)
    }

    @Test func theRouterStartsTheNextPersonOnHome() {
        let router = AppRouter(selectedTab: .inventory, inventoryFilter: .low)
        router.push(HomeRoute.account, on: .home)
        router.inventoryCategory = "Anesthetic"
        router.toBuyCount = 3
        router.reset()
        #expect(router.selectedTab == .home)
        for tab in AppTab.allCases {
            #expect(router.path(for: tab).isEmpty)
        }
        #expect(router.inventoryFilter == nil)
        #expect(router.inventoryCategory == nil)
        #expect(router.toBuyCount == 0)
    }

    @Test func initialsSkipATitle() {
        #expect(PersonName.initials(of: "Sarah Mitchell") == "SM")
        #expect(PersonName.initials(of: "Dr. Daniel Kim") == "DK")
        #expect(PersonName.initials(of: "michael reyes") == "MR")
        #expect(PersonName.initials(of: "Priya") == "P")
        #expect(PersonName.initials(of: "") == "")
    }
}
