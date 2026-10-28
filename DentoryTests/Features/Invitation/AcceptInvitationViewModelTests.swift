import Foundation
import Testing
@testable import Dentory

@MainActor
struct AcceptInvitationViewModelTests {
    private static let staffSession = Session(
        userID: UUID(), email: "priya@smiledental.ca", fullName: "Priya Patel", clinicID: Session.demo.clinicID,
        clinicName: "Smile Dental", role: .staff, currency: "USD", timeZone: "America/New_York"
    )

    private func make(
        auth: FakeAuthService = FakeAuthService(signInResult: .success(staffSession)),
        repository: FakeInvitationRepository = FakeInvitationRepository(),
        token: String = "token-1",
        analytics: SpyAnalytics = SpyAnalytics(),
        state: SessionStore.State = .signedOut,
        signingOut: FakeSigningOut = FakeSigningOut()
    ) -> (AcceptInvitationViewModel, SessionStore) {
        let store = SessionStore(auth: auth, state: state)
        let viewModel = AcceptInvitationViewModel(
            token: token, repository: repository, sessionStore: store, signingOut: signingOut, analytics: analytics
        )
        return (viewModel, store)
    }

    @Test func loadShowsTheInvitationAndPrefillsTheName() async {
        let repository = FakeInvitationRepository()
        let (viewModel, _) = make(repository: repository, token: "abc")
        #expect(viewModel.state == .loading)
        await viewModel.load()
        #expect(viewModel.state == .loaded(.fixture))
        #expect(viewModel.fullName == "Priya Patel")
        #expect(viewModel.caption == "Sarah Mitchell invited you as Staff. Set a password to finish.")
        #expect(repository.lookups == ["abc"])
    }

    @Test func anUnknownOrOldTokenReadsAsExpired() async {
        let (viewModel, _) = make(repository: FakeInvitationRepository(lookupResult: .success(nil)))
        await viewModel.load()
        #expect(viewModel.state == .expired)
        #expect(viewModel.invitation == nil)
        #expect(!viewModel.canJoin)
    }

    @Test func aFailedLoadCanBeRetried() async {
        let repository = FakeInvitationRepository(lookupResult: .failure(AppError.network))
        let (viewModel, _) = make(repository: repository)
        await viewModel.load()
        #expect(viewModel.state == .failed(.network))
        repository.lookupResult = .success(.fixture)
        await viewModel.load()
        #expect(viewModel.state == .loaded(.fixture))
    }

    @Test func joinNeedsANameAndEightCharacters() async {
        let (viewModel, _) = make(repository: FakeInvitationRepository(lookupResult: .success(
            Invitation(clinicName: "Smile Dental", invitedByName: "Sarah Mitchell", role: .admin,
                       email: "kim@smiledental.ca", fullName: "", expiresAt: Session.demoNow)
        )))
        await viewModel.load()
        #expect(viewModel.fullName.isEmpty)
        #expect(viewModel.caption == "Sarah Mitchell invited you as Admin. Set a password to finish.")
        #expect(!viewModel.canJoin)
        viewModel.fullName = "Dr. Daniel Kim"
        #expect(viewModel.passwordHint == nil)
        viewModel.password = "short"
        #expect(!viewModel.canJoin)
        #expect(viewModel.passwordHint == "At least 8 characters", "A disabled Join says why")
        viewModel.password = "longenough"
        #expect(viewModel.canJoin)
        #expect(viewModel.passwordHint == nil)
        viewModel.fullName = "   "
        #expect(!viewModel.canJoin)
    }

    @Test func joinAcceptsThenSignsInAsTheInvitee() async {
        let repository = FakeInvitationRepository()
        let auth = FakeAuthService(signInResult: .success(Self.staffSession))
        let analytics = SpyAnalytics()
        let (viewModel, store) = make(auth: auth, repository: repository, token: "token-9", analytics: analytics)
        await viewModel.load()
        viewModel.fullName = " Priya P. "
        viewModel.password = "smiledental"
        await viewModel.join()
        #expect(repository.accepts == [.init(token: "token-9", fullName: "Priya P.", password: "smiledental")])
        #expect(auth.signIns.count == 1)
        #expect(auth.signIns.first?.email == "priya@smiledental.ca")
        #expect(auth.signIns.first?.password == "smiledental")
        #expect(store.state == .signedIn(Self.staffSession))
        #expect(viewModel.isFinished)
        #expect(viewModel.generalError == nil)
        #expect(analytics.events == [.invitationAccepted], "MS-147: never the name or the password")
    }

    /// F4: joining over another member's session runs Sign out's clean-up first, so their cache, queued writes and push
    /// token never carry over to the invitee.
    @Test func joiningOverAnotherAccountRunsSignOutsCleanUpFirst() async {
        let auth = FakeAuthService(signInResult: .success(Self.staffSession))
        let signingOut = FakeSigningOut()
        var signInsBeforeCleanUp: Int?
        signingOut.onSignOut = { signInsBeforeCleanUp = auth.signIns.count }
        let (viewModel, store) = make(auth: auth, state: .signedIn(.demo), signingOut: signingOut)
        await viewModel.load()
        viewModel.password = "smiledental"
        await viewModel.join()
        #expect(signingOut.signOutCount == 1)
        #expect(signInsBeforeCleanUp == 0, "The clean-up runs while the previous member is still signed in")
        #expect(store.state == .signedIn(Self.staffSession))
    }

    @Test func joiningOnASignedOutDeviceOrAsTheSameAccountKeepsTheDevice() async {
        for state in [SessionStore.State.signedOut, .signedIn(Self.staffSession)] {
            let signingOut = FakeSigningOut()
            let (viewModel, _) = make(state: state, signingOut: signingOut)
            await viewModel.load()
            viewModel.password = "smiledental"
            await viewModel.join()
            #expect(viewModel.isFinished)
            #expect(signingOut.signOutCount == 0, "Nothing to clean for \(state)")
        }
    }

    @Test func aRefusedPasswordShowsUnderTheField() async {
        let repository = FakeInvitationRepository()
        repository.acceptResult = .failure(AppError.validation(field: "password", message: "At least 8 characters."))
        let auth = FakeAuthService(signInResult: .success(Self.staffSession))
        let (viewModel, store) = make(auth: auth, repository: repository)
        await viewModel.load()
        viewModel.fullName = "Priya"
        viewModel.password = "smiledental"
        await viewModel.join()
        #expect(viewModel.passwordError == "At least 8 characters.")
        #expect(auth.signIns.isEmpty)
        #expect(store.state == .signedOut)
        #expect(!viewModel.isFinished)
        viewModel.password = "smiledental2"
        #expect(viewModel.passwordError == nil)
    }

    @Test func anInvitationUsedMeanwhileReadsAsExpired() async {
        let repository = FakeInvitationRepository()
        repository.acceptResult = .failure(AppError.notFound)
        let auth = FakeAuthService(signInResult: .success(Self.staffSession))
        let (viewModel, _) = make(auth: auth, repository: repository)
        await viewModel.load()
        viewModel.fullName = "Priya"
        viewModel.password = "smiledental"
        await viewModel.join()
        #expect(viewModel.state == .expired)
        #expect(auth.signIns.isEmpty)
    }

    @Test func aRefusalWithoutAFieldBecomesAToast() async {
        let repository = FakeInvitationRepository()
        repository.acceptResult = .failure(AppError.forbidden)
        let (viewModel, _) = make(repository: repository)
        await viewModel.load()
        viewModel.fullName = "Priya"
        viewModel.password = "smiledental"
        await viewModel.join()
        #expect(viewModel.generalError == .forbidden)
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
        #expect(viewModel.state == .loaded(.fixture))
    }

    @Test func aFailedSignInAfterAcceptingIsReported() async {
        let auth = FakeAuthService(signInResult: .failure(AppError.network))
        let (viewModel, _) = make(auth: auth)
        await viewModel.load()
        viewModel.fullName = "Priya"
        viewModel.password = "smiledental"
        await viewModel.join()
        #expect(viewModel.generalError == .network)
        #expect(!viewModel.isFinished)
    }

    @Test func aSecondTapWhileJoiningIsIgnored() async {
        let repository = FakeInvitationRepository()
        repository.acceptDelay = .milliseconds(100)
        let (viewModel, _) = make(repository: repository)
        await viewModel.load()
        viewModel.fullName = "Priya"
        viewModel.password = "smiledental"
        async let first: Void = viewModel.join()
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.isSubmitting)
        await viewModel.join()
        await first
        #expect(repository.accepts.count == 1)
        #expect(viewModel.isFinished)
    }
}
