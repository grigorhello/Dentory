import Testing
@testable import MediSave

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
}
