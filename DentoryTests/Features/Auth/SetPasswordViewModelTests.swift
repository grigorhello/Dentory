import Foundation
import Testing
@testable import Dentory

@MainActor
struct SetPasswordViewModelTests {
    private func make(
        auth: FakeAuthService = FakeAuthService(),
        state: SessionStore.State = .signedOut,
        tokenHash: String = "pkce_ab12"
    ) -> (SetPasswordViewModel, SessionStore) {
        let store = SessionStore(auth: auth, state: state)
        return (SetPasswordViewModel(tokenHash: tokenHash, auth: auth, sessionStore: store), store)
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
        auth.verifyResult = .success(())
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
        viewModel.password = "12345678"
        #expect(viewModel.canSave)
    }

    @Test func savingSetsThePasswordAndSignsTheAccountIn() async {
        let auth = FakeAuthService()
        let (viewModel, store) = make(auth: auth)
        await viewModel.verifyIfNeeded()
        viewModel.password = "newpassword"
        await viewModel.save()
        #expect(auth.updatedPasswords == ["newpassword"])
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
}
