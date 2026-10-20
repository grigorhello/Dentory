import Foundation
import Testing
@testable import Dentory

/// Push on this device (PRD §8): the explainer, again 30 days after Not now, the iOS prompt behind "Turn on", the token
/// for the signed-in member, and the device signed out with them.
@MainActor
struct PushNotificationsTests {
    private let token = Data([0x0a, 0xff] + Array(repeating: 0x01, count: 30))
    private var tokenText: String { "0aff" + String(repeating: "01", count: 30) }

    private func make(
        _ authorizer: FakeNotificationAuthorizer = FakeNotificationAuthorizer(),
        repository: FakePushTokenRepository = FakePushTokenRepository(),
        store: InMemoryPushExplainerStore = InMemoryPushExplainerStore(),
        now: @escaping () -> Date = Date.init
    ) -> PushNotifications {
        PushNotifications(authorizer: authorizer, repository: repository, store: store, now: now)
    }

    @Test func aDeviceIOSHasNotAskedIsOfferedAgain30DaysAfterNotNow() async {
        let store = InMemoryPushExplainerStore()
        var clock = Session.demoNow
        let push = make(store: store, now: { clock })
        await push.signedIn(as: .demo)
        #expect(push.isExplainerPresented)
        #expect(store.lastOffered == clock, "A sheet swiped away counts as offered")
        push.notNow()

        clock += 29 * 24 * 60 * 60
        let soon = make(store: store, now: { clock })
        await soon.signedIn(as: .demo)
        #expect(soon.isExplainerPresented == false, "Not within 30 days")

        clock += 24 * 60 * 60
        let later = make(store: store, now: { clock })
        await later.signedIn(as: .demo)
        #expect(later.isExplainerPresented, "Again once 30 days passed, while iOS has not asked")
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

    @Test func signingOutRemovesTheDeviceEvenWhenThisLaunchCouldNotRegisterIt() async {
        let repository = FakePushTokenRepository()
        repository.failure = AppError.network
        let push = make(FakeNotificationAuthorizer(.allowed), repository: repository)
        await push.signedIn(as: .demo)
        await push.didRegister(deviceToken: token)
        repository.failure = nil
        await push.signOut()
        #expect(repository.removed == [tokenText], "The server may hold it from an earlier launch")
    }

    @Test func aDeviceThatChangesHandsWithoutSignOutBecomesTheNewMembers() async {
        let repository = FakePushTokenRepository()
        let push = make(FakeNotificationAuthorizer(.allowed), repository: repository)
        await push.signedIn(as: .demo)
        await push.didRegister(deviceToken: token)
        // Joining from an invitation, or a password reset, signs another member in here without Sign out.
        let michael = Session(
            userID: UUID(), email: "michael@smiledental.ca", fullName: "Michael Reyes", clinicID: Session.demo.clinicID,
            clinicName: "Smile Dental", role: .staff, currency: "USD", timeZone: "America/New_York"
        )
        await push.signedIn(as: michael)
        #expect(repository.registered == [tokenText, tokenText], "Registered again, now for Michael")
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
