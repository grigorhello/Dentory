import Foundation
import Testing
@testable import Dentory

/// Sign out leaves nothing of the clinic on the device (MS-137 acceptance): the cached answers, the queued writes and
/// a count in progress (MS-121) are gone, the device stops receiving the member's pushes (MS-144), the session has
/// ended, and the router starts the next person on Home.
@MainActor
struct DeviceSignOutTests {
    @Test func signingOutClearsTheDeviceAndEndsTheSession() async {
        let cache = InMemoryResponseCache()
        let key = CacheKey(method: "HomeRepository.summary", clinicID: Session.demo.clinicID)
        cache.store(HomeSummary.demo, for: key)
        let queue = PendingWriteQueue(store: InMemoryPendingWriteStore())
        _ = queue.enqueue(function: "stock_adjust", params: [:], key: UUID(), at: Session.demoNow)
        let store = SessionStore(auth: PreviewAuthService(session: .demo), state: .signedIn(.demo))
        let tokens = FakePushTokenRepository()
        let push = PushNotifications(
            authorizer: FakeNotificationAuthorizer(.allowed), repository: tokens, store: InMemoryPushExplainerStore()
        )
        await push.signedIn(as: .demo)
        await push.didRegister(deviceToken: Data(repeating: 0xab, count: 32))
        let logo = PendingClinicLogo()
        logo.keep(Data("png".utf8), for: Session.demo.clinicID)
        let count = StockCount(clinicID: Session.demo.clinicID, userID: Session.demo.userID)
        let draft = InMemoryCountDraftStore(draft: count)
        let signOut = DeviceSignOut(
            sessionStore: store, cache: cache, writes: queue, push: push, pendingLogo: logo, countDraft: draft
        )
        #expect(signOut.unsyncedChangeCount == 1)

        await signOut.signOut()

        #expect(cache.load(HomeSummary.self, for: key) == nil, "Cached clinic data is removed")
        #expect(queue.isEmpty, "Writes made offline are not sent under the next account")
        #expect(signOut.unsyncedChangeCount == 0)
        #expect(tokens.removed == [String(repeating: "ab", count: 32)], "This device gets no more of their pushes")
        #expect(logo.logo(for: Session.demo.clinicID) == nil, "A logo waiting for its retry is forgotten (MS-139)")
        #expect(draft.load() == nil, "A count in progress is not offered to the next person (MS-121)")
        #expect(store.state == .signedOut)
    }

    /// The server signing the member out here clears the same: a pending Clinic settings logo and a count go too.
    @Test func aRemovedMembersDeviceForgetsAPendingLogo() {
        let dependencies = AppDependencies.preview()
        dependencies.pendingClinicLogo.keep(Data("png".utf8), for: Session.demo.clinicID)
        dependencies.countDraftStore.save(StockCount(clinicID: Session.demo.clinicID, userID: Session.demo.userID))
        dependencies.clearClinicData()
        #expect(dependencies.pendingClinicLogo.logo(for: Session.demo.clinicID) == nil)
        #expect(dependencies.countDraftStore.load() == nil)
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
