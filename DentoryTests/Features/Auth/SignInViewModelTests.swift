import Foundation
import Testing
@testable import Dentory

@MainActor
struct SignInViewModelTests {
    private func makeViewModel(
        auth: FakeAuthService, analytics: SpyAnalytics = SpyAnalytics()
    ) -> (SignInViewModel, SessionStore) {
        let store = SessionStore(auth: auth, state: .signedOut)
        return (SignInViewModel(sessionStore: store, analytics: analytics), store)
    }

    @Test func submitIsDisabledUntilBothFieldsHaveText() {
        let (viewModel, _) = makeViewModel(auth: FakeAuthService())
        #expect(!viewModel.canSubmit)
        viewModel.email = "sarah@smiledental.ca"
        #expect(!viewModel.canSubmit)
        viewModel.password = "smiledental"
        #expect(viewModel.canSubmit)
        viewModel.email = "   "
        #expect(!viewModel.canSubmit)
    }

    @Test func aGoodSignInLandsOnHome() async {
        let auth = FakeAuthService()
        let (viewModel, store) = makeViewModel(auth: auth)
        viewModel.email = " sarah@smiledental.ca "
        viewModel.password = "smiledental"
        await viewModel.signIn()
        #expect(store.state == .signedIn(.demo))
        #expect(auth.signIns.first?.email == "sarah@smiledental.ca")
        #expect(viewModel.emailError == nil && viewModel.passwordError == nil && viewModel.generalError == nil)
    }

    @Test func onlyASignInThatWorkedIsCounted() async {
        let analytics = SpyAnalytics()
        let (viewModel, _) = makeViewModel(auth: FakeAuthService(), analytics: analytics)
        viewModel.email = "sarah@smiledental.ca"
        viewModel.password = "smiledental"
        await viewModel.signIn()
        #expect(analytics.events == [.signedIn])
        let refused = SpyAnalytics()
        let (failing, _) = makeViewModel(
            auth: FakeAuthService(signInResult: .failure(AppError.unknownEmail)), analytics: refused
        )
        failing.email = "nobody@smiledental.ca"
        failing.password = "smiledental"
        await failing.signIn()
        #expect(refused.events.isEmpty)
    }

    @Test func anUnknownEmailShowsUnderTheEmailField() async {
        let (viewModel, store) = makeViewModel(auth: FakeAuthService(signInResult: .failure(AppError.unknownEmail)))
        viewModel.email = "nobody@smiledental.ca"
        viewModel.password = "smiledental"
        await viewModel.signIn()
        #expect(viewModel.emailError == "No account with this email.")
        #expect(viewModel.passwordError == nil)
        #expect(store.state == .signedOut)
        viewModel.email = "sarah@smiledental.ca"
        #expect(viewModel.emailError == nil, "Typing clears the error")
    }

    @Test func aWrongPasswordShowsUnderThePasswordField() async {
        let (viewModel, _) = makeViewModel(auth: FakeAuthService(signInResult: .failure(AppError.wrongPassword)))
        viewModel.email = "sarah@smiledental.ca"
        viewModel.password = "nope"
        await viewModel.signIn()
        #expect(viewModel.passwordError == "Wrong password.")
        #expect(viewModel.emailError == nil)
    }

    @Test func aRevokedMembershipIsAToast() async {
        let (viewModel, _) = makeViewModel(auth: FakeAuthService(signInResult: .failure(AppError.forbidden)))
        viewModel.email = "priya@smiledental.ca"
        viewModel.password = "smiledental"
        await viewModel.signIn()
        #expect(viewModel.generalError == .forbidden)
        #expect(SignInViewModel.toastMessage(for: .forbidden) == "You no longer have access to this clinic.")
        #expect(SignInViewModel.toastMessage(for: .network) == AppError.network.userMessage)
    }

    @Test func aDoubleTapSignsInOnce() async throws {
        let auth = FakeAuthService()
        auth.signInDelay = .milliseconds(150)
        let (viewModel, _) = makeViewModel(auth: auth)
        viewModel.email = "sarah@smiledental.ca"
        viewModel.password = "smiledental"
        async let first: Void = viewModel.signIn()
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.isSubmitting)
        #expect(!viewModel.canSubmit)
        await viewModel.signIn()
        await first
        #expect(auth.signIns.count == 1)
        #expect(!viewModel.isSubmitting)
    }
}
