import Foundation
import Testing
@testable import Dentory

@MainActor
struct OnboardingViewModelTests {
    private func make(
        auth: FakeAuthService = FakeAuthService(),
        repository: FakeOnboardingRepository = FakeOnboardingRepository(),
        progress: InMemoryOnboardingProgress = InMemoryOnboardingProgress(),
        step: OnboardingViewModel.Step = .account,
        account: Account? = nil,
        clinicID: UUID? = nil,
        analytics: SpyAnalytics = SpyAnalytics()
    ) -> (OnboardingViewModel, SessionStore) {
        let store = SessionStore(auth: auth, state: .signedOut)
        let viewModel = OnboardingViewModel(
            auth: auth, repository: repository, sessionStore: store, progress: progress, analytics: analytics,
            locale: Locale(identifier: "en_CA"), timeZone: TimeZone(identifier: "America/Toronto") ?? .current,
            startingAt: step, account: account, clinicID: clinicID
        )
        return (viewModel, store)
    }

    @Test func continueNeedsANameAValidEmailAndEightCharacters() {
        let (viewModel, _) = make()
        viewModel.fullName = "Dr. Sarah Mitchell"
        viewModel.email = "sarah@clinic"
        viewModel.password = "smiledental"
        #expect(!viewModel.canContinueAccount)
        viewModel.email = "sarah@smiledental.ca"
        viewModel.password = "short"
        #expect(!viewModel.canContinueAccount)
        viewModel.password = "smiledental"
        #expect(viewModel.canContinueAccount)
    }

    @Test func step1CreatesTheAccountAndMovesOn() async {
        let auth = FakeAuthService()
        let (viewModel, store) = make(auth: auth)
        viewModel.fullName = " Dr. Sarah Mitchell "
        viewModel.email = " Sarah@SmileDental.ca "
        viewModel.password = "smiledental"
        await viewModel.createAccount()
        #expect(auth.signUps.first?.email == "sarah@smiledental.ca")
        #expect(auth.signUps.first?.fullName == "Dr. Sarah Mitchell")
        #expect(viewModel.step == .clinic)
        if case .needsClinic = store.state {} else { Issue.record("Store should wait for the clinic") }
    }

    @Test func aTakenEmailShowsUnderTheEmailField() async {
        let auth = FakeAuthService()
        auth.signUpResult = .failure(AppError.emailTaken)
        let (viewModel, _) = make(auth: auth)
        viewModel.fullName = "Sarah"
        viewModel.email = "sarah@smiledental.ca"
        viewModel.password = "smiledental"
        await viewModel.createAccount()
        #expect(viewModel.emailError == "An account with this email already exists. Sign in instead.")
        #expect(viewModel.step == .account)
    }

    @Test func aRefusedAddressShowsUnderItsRow() async {
        let repository = FakeOnboardingRepository()
        repository.inviteResult = .failure(
            AppError.validation(field: "priya@newclinic.ca", message: "priya@newclinic.ca is already on the team")
        )
        let (viewModel, _) = make(repository: repository, step: .invite, clinicID: Session.demo.clinicID)
        viewModel.invites[0].email = " Priya@NewClinic.ca "
        viewModel.invites[1].email = "kim@newclinic.ca"
        await viewModel.sendInvites()
        #expect(viewModel.invites[0].error == "priya@newclinic.ca is already on the team")
        #expect(viewModel.invites[1].error == nil)
        #expect(viewModel.generalError == nil)
        #expect(!viewModel.isFinished)
        viewModel.invites[0].email = "priya2@newclinic.ca"
        repository.inviteResult = .success(2)
        await viewModel.sendInvites()
        #expect(viewModel.isFinished)
    }

    @Test func theCountryDefaultsToTheDevice() {
        let (viewModel, _) = make()
        #expect(viewModel.country?.code == "CA")
        #expect(viewModel.countries.contains { $0.code == "US" })
    }

    @Test func step2CreatesTheClinicRemembersStep3AndRefreshesTheSession() async {
        let auth = FakeAuthService(storedSession: .demo)
        let repository = FakeOnboardingRepository()
        let progress = InMemoryOnboardingProgress()
        let account = Account(userID: UUID(), email: "sarah@smiledental.ca", fullName: "Sarah")
        let analytics = SpyAnalytics()
        let (viewModel, store) = make(
            auth: auth, repository: repository, progress: progress, step: .clinic, account: account,
            analytics: analytics
        )
        #expect(viewModel.email == "sarah@smiledental.ca")
        viewModel.clinicName = "Smile Dental"
        viewModel.city = "Toronto"
        viewModel.logoData = Data([1, 2, 3])
        #expect(viewModel.canCreateClinic)
        await viewModel.createClinic()
        #expect(repository.clinics.first?.country == "CA")
        #expect(repository.clinics.first?.timeZone == "America/Toronto")
        #expect(repository.clinics.first?.fullName == "Sarah")
        #expect(repository.logos == [Session.demo.clinicID])
        #expect(progress.pendingInviteClinicID() == Session.demo.clinicID, "Step 3 is remembered for a relaunch")
        #expect(store.state == .signedIn(.demo))
        #expect(viewModel.step == .invite)
        #expect(analytics.events == [.clinicCreated], "MS-147: once the clinic exists, never its name")
    }

    @Test func step3SendsOnlyFilledRowsAndFlagsBadOnes() async {
        let repository = FakeOnboardingRepository()
        repository.inviteResult = .success(2)
        let progress = InMemoryOnboardingProgress(pending: Session.demo.clinicID)
        let analytics = SpyAnalytics()
        let (viewModel, _) = make(
            repository: repository, progress: progress, step: .invite, clinicID: Session.demo.clinicID,
            analytics: analytics
        )
        viewModel.invites[0].email = "priya@smiledental.ca"
        viewModel.invites[1].email = "not an email"
        await viewModel.sendInvites()
        #expect(viewModel.invites[1].error == "Enter a valid email")
        #expect(repository.invites.isEmpty)

        viewModel.invites[1].email = ""
        viewModel.addInviteRow()
        viewModel.invites[2].email = "Kim@SmileDental.ca"
        viewModel.invites[2].role = .admin
        await viewModel.sendInvites()
        #expect(repository.invites.first?.invites == [
            TeamInvite(email: "priya@smiledental.ca", role: .staff),
            TeamInvite(email: "kim@smiledental.ca", role: .admin)
        ])
        #expect(viewModel.isFinished)
        #expect(viewModel.completionMessage == "Invitations sent · They get a link by email.")
        #expect(progress.pendingInviteClinicID() == nil)
        #expect(analytics.events == [.onboardingFinished(invitations: 2)], "Only the send that went out")
        #expect(analytics.events.first?.name.rawValue == "onboard.sendInvites")
    }

    @Test func skipClearsThePendingStepWithoutInviting() async {
        let repository = FakeOnboardingRepository()
        let progress = InMemoryOnboardingProgress(pending: Session.demo.clinicID)
        let analytics = SpyAnalytics()
        let (viewModel, _) = make(
            repository: repository, progress: progress, step: .invite, clinicID: Session.demo.clinicID,
            analytics: analytics
        )
        viewModel.skipInvites()
        #expect(analytics.events.map(\.name) == [.skipInvites])
        #expect(viewModel.isFinished)
        #expect(viewModel.completionMessage == nil)
        #expect(repository.invites.isEmpty)
        #expect(progress.pendingInviteClinicID() == nil)
    }

    @Test func emailShapes() {
        #expect(OnboardingViewModel.looksLikeEmail("a@b.co"))
        #expect(!OnboardingViewModel.looksLikeEmail("a@b"))
        #expect(!OnboardingViewModel.looksLikeEmail("@b.co"))
        #expect(!OnboardingViewModel.looksLikeEmail("a b@c.co"))
    }
}
