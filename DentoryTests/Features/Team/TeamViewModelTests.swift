import Foundation
import Testing
@testable import Dentory

/// Team (f31, f32): the rows' words, the admin's menu, the last admin kept, removal after a question, invitations, and
/// the session followed after the admin changes themselves.
@MainActor
struct TeamViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private var sarah: TeamMember { TeamMember.demo[0] }
    private var daniel: TeamMember { TeamMember.demo[1] }
    private var michael: TeamMember { TeamMember.demo[2] }
    private var priya: TeamMember { TeamMember.demo[3] }

    private func make(
        _ repository: FakeTeamRepository = FakeTeamRepository(), session: Session = .demo,
        cache: ResponseCaching = InMemoryResponseCache(), sessionChanged: @escaping () async -> Void = {}
    ) -> TeamViewModel {
        TeamViewModel(
            session: session, repository: repository, cache: cache, formatters: formatters,
            sessionChanged: sessionChanged
        )
    }

    @Test func rowsReadAsF31() async {
        let viewModel = make()
        await viewModel.load()
        #expect(viewModel.members.map { viewModel.title(for: $0) } == [
            "Sarah Mitchell", "Dr. Daniel Kim", "Michael Reyes", "priya@smiledental.ca"
        ])
        #expect(viewModel.subtitle(for: sarah) == "sarah@smiledental.ca")
        #expect(viewModel.subtitle(for: priya) == "Invited · Oct 1")
        let named = TeamMember(
            id: UUID(), userID: nil, fullName: "Anna Lee", email: "anna@smiledental.ca", role: .staff, status: .invited,
            invitedAt: Session.demoNow
        )
        #expect(viewModel.title(for: named) == "anna@smiledental.ca", "An invitation reads as its address")
        #expect(viewModel.initials(for: daniel) == "DK")
        #expect(viewModel.initials(for: priya) == "—")
        #expect(viewModel.identifier(for: sarah) == "team.member[00000000-0000-4000-8000-0000000000a1]")
        #expect(viewModel.identifier(for: priya).hasPrefix("team.member["), "An invitation goes by its own id")
        #expect(viewModel.changeRoleTitle(for: daniel) == "Change role to Staff")
        #expect(viewModel.changeRoleTitle(for: michael) == "Change role to Admin")
        #expect(viewModel.removeTitle(for: michael) == "Remove from clinic")
        #expect(viewModel.removeTitle(for: priya) == "Revoke invitation")
        #expect(viewModel.removeQuestion(for: michael) == "Remove Michael Reyes?")
        #expect(viewModel.removeMessage(for: michael) == "They lose access right away. Their history stays.")
        #expect(viewModel.removeQuestion(for: priya) == "Revoke the invitation to priya@smiledental.ca?")
    }

    @Test func staffReadTheListOnly() {
        let viewModel = make(session: .demo(role: .staff))
        #expect(viewModel.isAdmin == false)
        viewModel.openMenu(for: michael)
        #expect(viewModel.menuMember == nil, "No menu for Staff (f32)")
    }

    @Test func anAdminChangesARoleBothWays() async {
        let repository = FakeTeamRepository()
        let viewModel = make(repository)
        await viewModel.load()
        await viewModel.changeRole(of: daniel)
        await viewModel.changeRole(of: michael)
        #expect(repository.roleChanges.map(\.0) == [daniel.id, michael.id])
        #expect(repository.roleChanges.map(\.1) == [.staff, .admin])
        #expect(repository.loads == 3, "The list reloads after each change")
    }

    @Test func theLastAdminStays() async {
        let repository = FakeTeamRepository()
        repository.team = [sarah, michael, priya]
        let viewModel = make(repository)
        await viewModel.load()
        await viewModel.changeRole(of: sarah)
        #expect(viewModel.message?.title == "A clinic needs at least one admin.")
        viewModel.clearMessage()
        viewModel.askToRemove(sarah)
        #expect(viewModel.message?.title == "A clinic needs at least one admin.")
        #expect(viewModel.sheet == nil)
        #expect(repository.roleChanges.isEmpty && repository.removals.isEmpty, "Nothing reaches the server")
    }

    @Test func removingAsksFirst() async {
        let repository = FakeTeamRepository()
        let viewModel = make(repository)
        await viewModel.load()
        viewModel.askToRemove(michael)
        #expect(viewModel.sheet == .remove(michael))
        viewModel.keep()
        #expect(viewModel.sheet == nil)
        #expect(repository.removals.isEmpty, "Keep changes nothing")

        viewModel.askToRemove(michael)
        await viewModel.remove(michael)
        #expect(repository.removals == [michael.id])
        #expect(viewModel.sheet == nil)
    }

    @Test func resendingSendsTheSameInvitationAgain() async {
        let repository = FakeTeamRepository()
        let viewModel = make(repository)
        await viewModel.resend(priya)
        #expect(repository.invites == [.init(fullName: "", email: "priya@smiledental.ca", role: .staff)])
        #expect(viewModel.message == .init(title: "Invitation sent"))
    }

    @Test func anInvitationSentReloadsAndSaysWhatHappensNext() async {
        let repository = FakeTeamRepository()
        let viewModel = make(repository)
        viewModel.askToInvite()
        #expect(viewModel.sheet == .invite)
        await viewModel.didInvite()
        #expect(viewModel.sheet == nil)
        #expect(viewModel.message == .init(title: "Invitation sent", detail: "They get a link by email."))
        #expect(repository.loads == 1)
    }

    @Test func theServersRefusalIsShown() async {
        let repository = FakeTeamRepository()
        repository.failure = AppError.validation(field: nil, message: "This person is no longer on the team.")
        let viewModel = make(repository)
        await viewModel.changeRole(of: michael)
        #expect(viewModel.message?.title == "This person is no longer on the team.")
        repository.failure = AppError.network
        await viewModel.remove(michael)
        #expect(viewModel.message?.title == AppError.network.userMessage)
    }

    @Test func changingYourselfChecksTheSessionAgain() async {
        var checks = 0
        let viewModel = make(sessionChanged: { checks += 1 })
        await viewModel.load()
        await viewModel.changeRole(of: daniel)
        #expect(checks == 0, "Someone else's role leaves the session alone")
        await viewModel.changeRole(of: sarah)
        #expect(checks == 1, "The demo admin is Sarah")
        await viewModel.remove(sarah)
        #expect(checks == 2)
    }

    @Test func theCachedListShowsOfflineAndAFailureWithoutOneSaysWhy() async {
        let cache = InMemoryResponseCache()
        await make(cache: cache).load()
        let offline = FakeTeamRepository()
        offline.membersFailure = AppError.network
        let viewModel = make(offline, cache: cache)
        #expect(viewModel.members.count == 4, "The cached list shows at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        let nothingCached = make(offline)
        await nothingCached.load()
        #expect(nothingCached.state == .failed(.network))
    }
}
