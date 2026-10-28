import Foundation
import Testing
@testable import Dentory

@MainActor
struct SetPasswordViewModelTests {
    private static let michael = Session.demo(role: .staff)

    private func make(
        auth: FakeAuthService = FakeAuthService(),
        state: SessionStore.State = .signedOut,
        tokenHash: String = "pkce_ab12",
        signingOut: FakeSigningOut = FakeSigningOut()
    ) -> (SetPasswordViewModel, SessionStore) {
        let store = SessionStore(auth: auth, state: state)
        let viewModel = SetPasswordViewModel(
            tokenHash: tokenHash, auth: auth, sessionStore: store, signingOut: signingOut
        )
        return (viewModel, store)
    }

    @Test func aGoodLinkIsCheckedOnceAndOpensTheForm() async {
        let auth = FakeAuthService()
        let (viewModel, _) = make(auth: auth, tokenHash: "h1")
        #expect(viewModel.state == .verifying)
        await viewModel.verifyIfNeeded()
        #expect(viewModel.state == .ready)
        await viewModel.verifyIfNeeded()
        #expect(auth.verifiedTokenHashes == ["h1"], "The link's token works once; reopening must not spend it again")
    }

    @Test func anExpiredOrUsedLinkShowsTheExpiredState() async {
        let auth = FakeAuthService()
        auth.verifyResult = .failure(AppError.notFound)
        let (viewModel, _) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        #expect(viewModel.state == .expired)
        #expect(!viewModel.canSave)
    }

    @Test func aNetworkFailureCanBeRetried() async {
        let auth = FakeAuthService()
        auth.verifyResult = .failure(AppError.network)
        let (viewModel, _) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        #expect(viewModel.state == .failed(.network))
        auth.verifyResult = .success(.demoLink)
        await viewModel.verify()
        #expect(viewModel.state == .ready)
        #expect(auth.verifiedTokenHashes.count == 2)
    }

    @Test func saveWaitsForEightCharacters() async {
        let (viewModel, _) = make()
        viewModel.password = "longenough"
        #expect(!viewModel.canSave, "Nothing is saved before the link is checked")
        await viewModel.verifyIfNeeded()
        viewModel.password = "short"
        #expect(!viewModel.canSave)
        #expect(viewModel.passwordHint == "At least 8 characters", "A disabled Save password says why")
        viewModel.password = "12345678"
        #expect(viewModel.canSave)
        #expect(viewModel.passwordHint == nil)
    }

    @Test func savingSetsThePasswordAndSignsTheAccountIn() async {
        let auth = FakeAuthService()
        let (viewModel, store) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(auth.updatedPasswords == ["newpassword"])
        #expect(auth.linkSignIns == [.demoLink], "The link's account signs in once the password is saved")
        #expect(store.state == .signedIn(.demo), "The session reloads, so Home is next")
        #expect(viewModel.isFinished)
        #expect(viewModel.passwordError == nil && viewModel.generalError == nil)
    }

    @Test func aRefusedPasswordShowsUnderTheField() async {
        let auth = FakeAuthService()
        auth.updatePasswordResult = .failure(AppError.samePassword)
        let (viewModel, store) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "smiledental"
        await viewModel.save()
        #expect(viewModel.passwordError == "Choose a new password, not the current one.")
        #expect(!viewModel.isFinished)
        #expect(store.state == .signedOut)
        viewModel.password = "smiledental2"
        #expect(viewModel.passwordError == nil, "Typing clears the error")
    }

    @Test func aFailedSaveIsAToastAndKeepsTheInput() async {
        let auth = FakeAuthService()
        auth.updatePasswordResult = .failure(AppError.network)
        let (viewModel, _) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(viewModel.generalError == .network)
        #expect(viewModel.password == "newpassword")
        #expect(!viewModel.isFinished)
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }

    @Test func aRevokedAccountLandsOnSignInWithTheRevokedToast() async {
        let auth = FakeAuthService()
        auth.sessionAfterReset = nil
        auth.restoreError = AppError.forbidden
        let (viewModel, store) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(viewModel.isFinished, "The password is saved even when the clinic membership is gone")
        #expect(store.state == .signedOut)
        #expect(store.accessWasRevoked)
    }

    // MARK: Security review F4

    @Test func theReadyStateNamesTheLinksAccount() async {
        let (viewModel, _) = make()
        await viewModel.verifyIfNeeded()
        #expect(viewModel.caption == "Choose a password for sarah@smiledental.ca")
    }

    @Test func openingTheLinkLeavesTheSignedInAccountAsItIs() async {
        let auth = FakeAuthService(storedSession: Self.michael)
        let signingOut = FakeSigningOut()
        let (viewModel, store) = make(auth: auth, state: .signedIn(Self.michael), signingOut: signingOut)
        await viewModel.verifyIfNeeded()
        #expect(viewModel.state == .ready)
        #expect(store.state == .signedIn(Self.michael), "Only a saved password signs the link's account in")
        #expect(auth.storedSession == Self.michael)
        #expect(auth.linkSignIns.isEmpty)
        #expect(signingOut.signOutCount == 0)
    }

    @Test func theWayOutLeadsToSignInOrBackToTheAccountSignedInHere() async {
        let (signedOut, _) = make()
        #expect(signedOut.leavesToSignIn)
        let (signedIn, _) = make(state: .signedIn(Self.michael))
        #expect(!signedIn.leavesToSignIn, "Cancel goes back to the account still signed in")
        let (newClinic, _) = make(state: .needsClinic(Account(userID: UUID(), email: "a@b.ca", fullName: "A")))
        #expect(!newClinic.leavesToSignIn)
    }

    @Test func savingOverAnotherAccountRunsSignOutsCleanUpBeforeTheSignIn() async {
        let auth = FakeAuthService(storedSession: Self.michael)
        let signingOut = FakeSigningOut()
        var linkSignInsBeforeCleanUp: Int?
        signingOut.onSignOut = { linkSignInsBeforeCleanUp = auth.linkSignIns.count }
        let (viewModel, store) = make(auth: auth, state: .signedIn(Self.michael), signingOut: signingOut)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(signingOut.signOutCount == 1, "Michael's cache, queued writes and push token do not carry over")
        #expect(linkSignInsBeforeCleanUp == 0, "The clean-up runs while Michael's session can still drop his token")
        #expect(store.state == .signedIn(.demo))
        #expect(viewModel.isFinished)
    }

    @Test func savingAsTheSignedInAccountKeepsTheDevice() async {
        let auth = FakeAuthService(storedSession: .demo)
        let signingOut = FakeSigningOut()
        let (viewModel, store) = make(auth: auth, state: .signedIn(.demo), signingOut: signingOut)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(signingOut.signOutCount == 0)
        #expect(store.state == .signedIn(.demo))
        #expect(viewModel.isFinished)
    }

    @Test func aRefusedPasswordLeavesTheSignedInAccountAlone() async {
        let auth = FakeAuthService(storedSession: Self.michael)
        auth.updatePasswordResult = .failure(AppError.leakedPassword)
        let signingOut = FakeSigningOut()
        let (viewModel, store) = make(auth: auth, state: .signedIn(Self.michael), signingOut: signingOut)
        await viewModel.verifyIfNeeded()
        viewModel.password = "password1"
        await viewModel.save()
        #expect(signingOut.signOutCount == 0)
        #expect(auth.linkSignIns.isEmpty)
        #expect(store.state == .signedIn(Self.michael))
    }

    @Test func aFailedSignInAfterSavingRetriesOnlyTheSignIn() async {
        let auth = FakeAuthService()
        auth.linkSignInResult = .failure(AppError.network)
        let (viewModel, store) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(viewModel.generalError == .network)
        #expect(!viewModel.isFinished)
        auth.linkSignInResult = .success(())
        await viewModel.save()
        #expect(auth.updatedPasswords == ["newpassword"], "The saved password is not sent again")
        #expect(auth.linkSignIns.count == 2)
        #expect(store.state == .signedIn(.demo))
        #expect(viewModel.isFinished)
    }

    @Test func aRecoverySessionThatRanOutBeforeSavingReadsAsExpired() async {
        let auth = FakeAuthService()
        auth.updatePasswordResult = .failure(AppError.notFound)
        let (viewModel, _) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(viewModel.state == .expired)
        #expect(!viewModel.isFinished)
    }

    @Test func aRecoverySessionThatRanOutAfterSavingEndsOnSignIn() async {
        let auth = FakeAuthService()
        auth.linkSignInResult = .failure(AppError.notFound)
        let (viewModel, store) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(viewModel.isFinished, "The password is saved; it signs in from Sign in")
        #expect(viewModel.generalError == nil)
        #expect(store.state == .signedOut)
    }
}
