import Foundation
import Testing
@testable import Dentory

/// Invite a teammate (Appendix C `invite`): the address checked first, Staff by default, the server's refusal under
/// the field, and the list told once the email went out.
@MainActor
struct InviteTeammateViewModelTests {
    private func make(
        _ repository: FakeTeamRepository = FakeTeamRepository(), analytics: SpyAnalytics = SpyAnalytics(),
        onSent: @escaping () async -> Void = {}
    ) -> InviteTeammateViewModel {
        InviteTeammateViewModel(
            clinicID: Session.demo.clinicID, repository: repository, analytics: analytics, onSent: onSent
        )
    }

    @Test func sendsTheTrimmedAddressWithStaffByDefault() async {
        var sent = 0
        let repository = FakeTeamRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(repository, analytics: analytics, onSent: { sent += 1 })
        #expect(viewModel.canSend == false, "Nothing to send without an address")
        #expect(viewModel.role == .staff)
        viewModel.name = "  Priya Shah "
        viewModel.email = " Priya@SmileDental.ca "
        #expect(viewModel.canSend)
        await viewModel.send()
        #expect(repository.invites == [.init(fullName: "Priya Shah", email: "priya@smiledental.ca", role: .staff)])
        #expect(sent == 1)
        #expect(analytics.events == [.teammateInvited(role: .staff)], "The role, never the name or the address")
        #expect(analytics.events.first?.payload == ["role": .text("staff")])
    }

    @Test func aMalformedAddressIsSaidUnderTheField() async {
        let repository = FakeTeamRepository()
        let viewModel = make(repository)
        viewModel.email = "priya@"
        await viewModel.send()
        #expect(viewModel.emailError == "Enter a valid email")
        #expect(repository.invites.isEmpty)
        viewModel.email = "priya@smiledental.ca"
        #expect(viewModel.emailError == nil, "Typing clears it")
    }

    @Test func anAddressOnTheTeamIsSaidUnderTheFieldAndOtherRefusalsInTheSheet() async {
        var sent = 0
        let repository = FakeTeamRepository()
        let refusal = "michael@smiledental.ca is already on the team"
        repository.failure = AppError.validation(field: "email", message: refusal)
        let viewModel = make(repository, onSent: { sent += 1 })
        viewModel.email = "michael@smiledental.ca"
        viewModel.role = .admin
        await viewModel.send()
        #expect(viewModel.emailError == refusal)
        #expect(sent == 0)
        repository.failure = AppError.readOnly
        await viewModel.send()
        #expect(viewModel.generalError == .readOnly)
        #expect(viewModel.email == "michael@smiledental.ca", "What was typed stays")
        viewModel.name = "Michael"
        #expect(viewModel.generalError == nil, "Editing clears it")

        repository.failure = AppError.network
        await viewModel.send()
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.", "Not queued, so nothing is retried")
    }
}
