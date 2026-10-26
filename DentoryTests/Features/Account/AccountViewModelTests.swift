import Foundation
import Testing
@testable import Dentory

/// Account (f29, f30): the user card, the team's size and its cache, the role's rows, Export CSV, and Sign out.
@MainActor
struct AccountViewModelTests {
    private func make(
        session: Session = .demo,
        repository: FakeAccountRepository = FakeAccountRepository(),
        cache: ResponseCaching = InMemoryResponseCache(),
        signingOut: FakeSigningOut = FakeSigningOut(),
        analytics: SpyAnalytics = SpyAnalytics()
    ) -> AccountViewModel {
        AccountViewModel(
            session: session, repository: repository, cache: cache, signingOut: signingOut, analytics: analytics
        )
    }

    @Test func theCardReadsWhoIsSignedIn() {
        let admin = make()
        #expect(admin.initials == "SM")
        #expect(admin.name == "Sarah Mitchell")
        #expect(admin.roleLine == "Admin\u{00A0}· Smile Dental")
        #expect(admin.isAdmin)
        let staff = make(session: .demo(role: .staff))
        #expect(staff.initials == "MR")
        #expect(staff.roleLine == "Staff\u{00A0}· Smile Dental")
        #expect(staff.isAdmin == false, "Staff get Team, Help and Sign out only (f30)")
    }

    @Test func anAccountWithoutANameShowsItsAddress() {
        let session = Session(
            userID: UUID(), email: "priya@smiledental.ca", fullName: "", clinicID: Session.demo.clinicID,
            clinicName: "Smile Dental", role: .staff, currency: "USD", timeZone: "America/New_York"
        )
        let viewModel = make(session: session)
        #expect(viewModel.initials == "P")
        #expect(viewModel.name == "priya@smiledental.ca")
    }

    @Test func theTeamRowCountsPeopleOnceLoaded() async {
        let repository = FakeAccountRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.teamText == nil, "No number before an answer")
        await viewModel.load()
        #expect(viewModel.teamText == "3 people")
        #expect(repository.calls == [Session.demo.clinicID])
        let alone = make(repository: FakeAccountRepository(result: .success(1)))
        await alone.load()
        #expect(alone.teamText == "1 person")
    }

    @Test func theLastSizeShowsOffline() async {
        let cache = InMemoryResponseCache()
        await make(cache: cache).load()
        let offline = make(repository: FakeAccountRepository(result: .failure(AppError.network)), cache: cache)
        #expect(offline.teamText == "3 people", "The cached size shows at once")
        await offline.load()
        #expect(offline.teamText == "3 people")
        let nothingCached = make(repository: FakeAccountRepository(result: .failure(AppError.network)))
        await nothingCached.load()
        #expect(nothingCached.teamText == nil)
    }

    @Test func signingOutAsksFirst() async {
        let signingOut = FakeSigningOut()
        let viewModel = make(signingOut: signingOut)
        viewModel.askToSignOut()
        #expect(viewModel.isConfirmingSignOut)
        viewModel.keep()
        #expect(viewModel.isConfirmingSignOut == false)
        #expect(signingOut.signOutCount == 0, "Keep changes nothing")
        viewModel.askToSignOut()
        await viewModel.signOut()
        #expect(signingOut.signOutCount == 1)
        #expect(viewModel.isSigningOut)
        await viewModel.signOut()
        #expect(signingOut.signOutCount == 1, "A second tap does not sign out twice")
    }

    @Test func theConfirmationSaysWhatOfflineChangesLose() {
        let signingOut = FakeSigningOut()
        let viewModel = make(signingOut: signingOut)
        #expect(viewModel.signOutMessage == "You can sign in again with your email.")
        signingOut.unsyncedChangeCount = 1
        #expect(viewModel.signOutMessage == "You can sign in again with your email. "
            + "1 change made offline has not synced and will be lost.")
        signingOut.unsyncedChangeCount = 3
        #expect(viewModel.signOutMessage.hasSuffix("3 changes made offline have not synced and will be lost."))
    }

    @Test func helpOpensTheHelpCentre() {
        #expect(AccountViewModel.helpCentre?.absoluteString == "https://dentory.ca/help")
    }

    @Test func anExportSaysWhereTheLinkGoes() async {
        let repository = FakeAccountRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(repository: repository, analytics: analytics)
        await viewModel.startExport()
        #expect(analytics.events == [.exportStarted], "MS-147")
        #expect(repository.exportCalls == [Session.demo.clinicID])
        #expect(viewModel.message == .init(title: "Export started", detail: "We'll email it to sarah@dentory.test."))
        #expect(viewModel.isExporting == false)
        viewModel.clearMessage()
        #expect(viewModel.message == nil)
        let noAddress = make(repository: FakeAccountRepository(exportResult: .success("")))
        await noAddress.startExport()
        #expect(noAddress.message?.detail == "We'll email it to sarah@smiledental.ca.", "The session's address")
    }

    @Test func aRefusedExportSaysWhy() async {
        let limit = AppError.validation(
            field: nil, message: "An export started less than 10 minutes ago. It is on its way to your email."
        )
        let limited = make(repository: FakeAccountRepository(exportResult: .failure(limit)))
        await limited.startExport()
        #expect(limited.message == .init(title: "An export started less than 10 minutes ago. "
            + "It is on its way to your email."))
        let offline = make(repository: FakeAccountRepository(exportResult: .failure(AppError.network)))
        await offline.startExport()
        #expect(offline.message?.title == "Couldn't start the export. Try again.")
        #expect(offline.message?.detail == nil)
        #expect(AccountViewModel.exportRefusal(.forbidden) == "You don't have permission to do this.")
        #expect(AccountViewModel.exportRefusal(.unknown("500")) == "Couldn't start the export. Try again.")
    }

    @Test func staffCannotStartAnExport() async {
        let repository = FakeAccountRepository()
        let viewModel = make(session: .demo(role: .staff), repository: repository)
        await viewModel.startExport()
        #expect(repository.exportCalls.isEmpty, "The row is hidden from Staff; the view model refuses too")
        #expect(viewModel.message == nil)
    }
}
