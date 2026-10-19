import Foundation
import Testing
@testable import Dentory

@MainActor
struct ResetPasswordViewModelTests {
    @Test func theEmailComesPrefilledFromSignIn() {
        let viewModel = ResetPasswordViewModel(email: "  sarah@smiledental.ca ", auth: FakeAuthService())
        #expect(viewModel.email == "sarah@smiledental.ca")
        #expect(viewModel.canSend)
        #expect(viewModel.confirmation == nil)
    }

    @Test func sendIsDisabledWithoutAnEmail() {
        let viewModel = ResetPasswordViewModel(email: "", auth: FakeAuthService())
        #expect(!viewModel.canSend)
        viewModel.email = "   "
        #expect(!viewModel.canSend)
        viewModel.email = "sarah@smiledental.ca"
        #expect(viewModel.canSend)
    }

    @Test func sendingAsksForTheLinkAndConfirmsWithoutSayingWhetherTheAccountExists() async {
        let auth = FakeAuthService()
        let viewModel = ResetPasswordViewModel(email: "", auth: auth)
        viewModel.email = " nobody@smiledental.ca "
        await viewModel.send()
        #expect(auth.resetEmails == ["nobody@smiledental.ca"])
        #expect(viewModel.confirmation == "If an account exists for nobody@smiledental.ca, a link is on its way.")
        #expect(viewModel.emailError == nil && viewModel.generalError == nil)
    }

    @Test func editingTheEmailClearsTheConfirmation() async {
        let viewModel = ResetPasswordViewModel(email: "sarah@smiledental.ca", auth: FakeAuthService())
        await viewModel.send()
        #expect(viewModel.confirmation != nil)
        viewModel.email = "michael@smiledental.ca"
        #expect(viewModel.confirmation == nil, "The sentence names the address the link went to")
    }

    @Test func aMalformedAddressShowsUnderTheField() async {
        let auth = FakeAuthService()
        auth.resetResult = .failure(AppError.invalidEmail)
        let viewModel = ResetPasswordViewModel(email: "sarah", auth: auth)
        await viewModel.send()
        #expect(viewModel.emailError == "Enter a valid email address.")
        #expect(viewModel.confirmation == nil)
        viewModel.email = "sarah@smiledental.ca"
        #expect(viewModel.emailError == nil, "Typing clears the error")
    }

    @Test func tooManyRequestsShowUnderTheField() async {
        let auth = FakeAuthService()
        auth.resetResult = .failure(AppError.tooManyResetLinks)
        let viewModel = ResetPasswordViewModel(email: "sarah@smiledental.ca", auth: auth)
        await viewModel.send()
        #expect(viewModel.emailError == "Too many links sent. Wait a minute, then try again.")
    }

    @Test func aNetworkFailureIsAToastAndKeepsTheInput() async {
        let auth = FakeAuthService()
        auth.resetResult = .failure(AppError.network)
        let viewModel = ResetPasswordViewModel(email: "sarah@smiledental.ca", auth: auth)
        await viewModel.send()
        #expect(viewModel.generalError == .network)
        #expect(viewModel.email == "sarah@smiledental.ca")
        #expect(viewModel.confirmation == nil)
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }
}
