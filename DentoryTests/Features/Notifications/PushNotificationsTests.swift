import Foundation
import Testing
@testable import Dentory

/// Push on this device (PRD §8): the explainer once, the iOS prompt behind "Turn on", the token for the signed-in
/// member, and the device signed out with them.
@MainActor
struct PushNotificationsTests {
    private let token = Data([0x0a, 0xff] + Array(repeating: 0x01, count: 30))
    private var tokenText: String { "0aff" + String(repeating: "01", count: 30) }

    private func make(
        _ authorizer: FakeNotificationAuthorizer = FakeNotificationAuthorizer(),
        repository: FakePushTokenRepository = FakePushTokenRepository(),
        store: InMemoryPushExplainerStore = InMemoryPushExplainerStore()
    ) -> PushNotifications {
        PushNotifications(authorizer: authorizer, repository: repository, store: store)
    }

    @Test func aDeviceIOSHasNotAskedOffersNotificationsOnce() async {
        let store = InMemoryPushExplainerStore()
        let push = make(store: store)
        await push.signedIn(as: .demo)
        #expect(push.isExplainerPresented)
        #expect(store.hasOffered, "A sheet swiped away is not offered again")

        let again = make(store: store)
        await again.signedIn(as: .demo)
        #expect(again.isExplainerPresented == false)
    }

    @Test func turnOnShowsTheIOSPromptThenAsksForTheToken() async {
        let authorizer = FakeNotificationAuthorizer()
        let push = make(authorizer)
        await push.signedIn(as: .demo)
        await push.turnOn()
        #expect(push.isExplainerPresented == false)
        #expect(authorizer.prompts == 1)
        #expect(authorizer.registrations == 1)

        let refused = FakeNotificationAuthorizer(allows: false)
        let declined = make(refused)
        await declined.signedIn(as: .demo)
        await declined.turnOn()
        #expect(refused.registrations == 0, "No token without permission")
    }

    @Test func notNowClosesWithoutThePrompt() async {
        let authorizer = FakeNotificationAuthorizer()
        let push = make(authorizer)
        await push.signedIn(as: .demo)
        push.notNow()
        #expect(push.isExplainerPresented == false)
        #expect(authorizer.prompts == 0)
    }

    @Test func allowedRefreshesTheTokenAndDeniedStaysQuiet() async {
        let allowed = FakeNotificationAuthorizer(.allowed)
        let push = make(allowed)
        await push.signedIn(as: .demo)
        #expect(push.isExplainerPresented == false)
        #expect(allowed.registrations == 1)

        let denied = FakeNotificationAuthorizer(.denied)
        let quiet = make(denied)
        await quiet.signedIn(as: .demo)
        #expect(quiet.isExplainerPresented == false)
        #expect(denied.registrations == 0)
    }

    @Test func theTokenGoesToTheServerOncePerMember() async {
        let repository = FakePushTokenRepository()
        let push = make(FakeNotificationAuthorizer(.allowed), repository: repository)
        await push.didRegister(deviceToken: token)
        #expect(repository.registered.isEmpty, "Not before sign-in")
        await push.signedIn(as: .demo)
        #expect(repository.registered == [tokenText], "Hex, as APNs addresses the device")
        await push.didRegister(deviceToken: token)
        #expect(repository.registered.count == 1, "The same token is not sent twice")
    }

    @Test func signingOutRemovesThisDeviceAndTheNextMemberRegistersIt() async {
        let repository = FakePushTokenRepository()
        let push = make(FakeNotificationAuthorizer(.allowed), repository: repository)
        await push.signedIn(as: .demo)
        await push.didRegister(deviceToken: token)
        await push.signOut()
        #expect(repository.removed == [tokenText])
        await push.didRegister(deviceToken: token)
        #expect(repository.registered.count == 1, "Signed out, the token stays off the server")
        await push.signedIn(as: .demo(role: .staff))
        #expect(repository.registered == [tokenText, tokenText])
    }

    @Test func aFailedUploadIsTriedAgain() async {
        let repository = FakePushTokenRepository()
        repository.failure = AppError.network
        let push = make(FakeNotificationAuthorizer(.allowed), repository: repository)
        await push.signedIn(as: .demo)
        await push.didRegister(deviceToken: token)
        repository.failure = nil
        await push.didRegister(deviceToken: token)
        #expect(repository.registered == [tokenText])
    }

    @Test func staffAreNotPromisedDeliveryAlerts() async {
        let push = make()
        await push.signedIn(as: .demo)
        #expect(push.explainerText == "Get alerts for out-of-stock items, expiring stock and invoices ready to review.")
        let staff = make()
        await staff.signedIn(as: .demo(role: .staff))
        #expect(staff.explainerText == "Get alerts for out-of-stock items and expiring stock.")
    }

    @Test func aTappedNotificationWaitsForTheTabs() {
        let push = make()
        let id = UUID()
        push.open(.product(id))
        #expect(push.pendingLink == .product(id))
    }
}
