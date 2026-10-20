import Foundation
import Testing
@testable import Dentory

@MainActor
struct SessionStoreTests {
    @Test func restoresAStoredSession() async {
        let store = SessionStore(auth: FakeAuthService(storedSession: .demo))
        #expect(store.state == .restoring)
        await store.restore()
        #expect(store.state == .signedIn(.demo))
        #expect(store.session?.clinicName == "Smile Dental")
    }

    @Test func noStoredSessionMeansSignedOut() async {
        let store = SessionStore(auth: FakeAuthService(storedSession: nil))
        await store.restore()
        #expect(store.state == .signedOut)
        #expect(store.lastError == nil)
    }

    @Test func aFailedRestoreSignsOutAndKeepsTheError() async {
        let auth = FakeAuthService()
        auth.restoreError = AppError.network
        let store = SessionStore(auth: auth)
        await store.restore()
        #expect(store.state == .signedOut)
        #expect(store.lastError == .network)
    }

    @Test func aRevokedMembershipSignsOutAndRemembersWhy() async {
        let auth = FakeAuthService(storedSession: .demo)
        auth.restoreError = AppError.forbidden
        let store = SessionStore(auth: auth)
        await store.restore()
        #expect(store.state == .signedOut)
        #expect(store.accessWasRevoked)
        store.acknowledgeRevokedAccess()
        #expect(!store.accessWasRevoked)
    }

    @Test func aUserWithoutAClinicResumesSignUp() async {
        let account = Account(userID: UUID(), email: "owner@newclinic.ca", fullName: "Sarah")
        let auth = FakeAuthService()
        auth.storedAccount = account
        let store = SessionStore(auth: auth)
        await store.restore()
        #expect(store.state == .needsClinic(account))
        #expect(!store.accessWasRevoked)
    }

    @Test func signInAndOut() async {
        let auth = FakeAuthService()
        let store = SessionStore(auth: auth, state: .signedOut)
        #expect(await store.signIn(email: "michael@smiledental.test", password: "hunter2hunter2"))
        #expect(store.state == .signedIn(.demo))
        #expect(auth.signIns.count == 1)
        await store.signOut()
        #expect(store.state == .signedOut)
        #expect(auth.signOutCount == 1)
    }

    @Test func aRefusedSignInReportsTheError() async {
        let store = SessionStore(auth: FakeAuthService(signInResult: .failure(AppError.forbidden)), state: .signedOut)
        #expect(await store.signIn(email: "x@y.test", password: "nope") == false)
        #expect(store.state == .signedOut)
        #expect(store.lastError == .forbidden)
    }

    /// MS-138: back in the foreground, or after an admin changed their own role, the server's answer wins.
    @Test func revalidatingFollowsARoleChangeAndARemoval() async {
        let auth = FakeAuthService(storedSession: .demo)
        let store = SessionStore(auth: auth, state: .signedIn(.demo))
        auth.storedSession = .demo(role: .staff)
        await store.revalidate()
        #expect(store.state == .signedIn(.demo(role: .staff)), "The new role shows at once")

        auth.restoreError = AppError.network
        await store.revalidate()
        #expect(store.state == .signedIn(.demo(role: .staff)), "Offline, the session stays")

        auth.restoreError = AppError.forbidden
        await store.revalidate()
        #expect(store.state == .signedOut, "Removed from the clinic")
        #expect(store.accessWasRevoked, "Sign in says why")
    }
}
