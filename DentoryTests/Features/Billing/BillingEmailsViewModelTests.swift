import Foundation
import Testing
@testable import Dentory

/// The billing emails sheet (MS-141): the first address kept, Add with its checks, Remove, and Done.
@MainActor
struct BillingEmailsViewModelTests {
    private func make(
        _ repository: FakeBillingRepository = FakeBillingRepository(), onSaved: @escaping () async -> Void = {}
    ) async -> BillingEmailsViewModel {
        let viewModel = BillingEmailsViewModel(
            clinicID: Session.demo.clinicID, repository: repository, onSaved: onSaved
        )
        await viewModel.load()
        return viewModel
    }

    @Test func thePrimaryComesFirstAndTheOthersAfter() async {
        let repository = FakeBillingRepository()
        repository.emails = ["owner@smiledental.ca", "books@smiledental.ca"]
        let viewModel = await make(repository)
        #expect(viewModel.primary == "owner@smiledental.ca")
        #expect(viewModel.extra == ["books@smiledental.ca"])
        #expect(!viewModel.hasChanges)
    }

    @Test func addChecksTheAddressAndListsIt() async {
        let viewModel = await make()
        #expect(!viewModel.canAdd)
        viewModel.newEmail = "books@smile"
        viewModel.add()
        #expect(viewModel.emailError == "Enter a valid email")
        viewModel.newEmail = " Books@SmileDental.ca "
        #expect(viewModel.emailError == nil, "Typing clears it")
        viewModel.add()
        #expect(viewModel.extra == ["books@smiledental.ca"])
        #expect(viewModel.newEmail.isEmpty)
        viewModel.newEmail = "BOOKS@smiledental.ca"
        viewModel.add()
        #expect(viewModel.emailError == "This address is already on the list")
        viewModel.newEmail = "owner@smiledental.ca"
        viewModel.add()
        #expect(viewModel.emailError == "This address is already on the list", "The primary too")
        #expect(viewModel.hasChanges)
    }

    @Test func tenAddressesAtMost() async {
        let viewModel = await make()
        for number in 1...9 {
            viewModel.newEmail = "a\(number)@smile.ca"
            viewModel.add()
        }
        #expect(viewModel.extra.count == 9)
        viewModel.newEmail = "a10@smile.ca"
        viewModel.add()
        #expect(viewModel.emailError == "Up to 10 billing emails")
        #expect(viewModel.extra.count == 9)
    }

    @Test func doneSavesTheListAndSaysSo() async {
        let repository = FakeBillingRepository()
        repository.emails = ["owner@smiledental.ca", "old@smiledental.ca"]
        var refreshed = 0
        let viewModel = await make(repository, onSaved: { refreshed += 1 })
        viewModel.remove("old@smiledental.ca")
        viewModel.newEmail = "books@smiledental.ca"
        viewModel.add()
        await viewModel.save()
        #expect(repository.saves == [["books@smiledental.ca"]])
        #expect(viewModel.outcome == .saved, "The toast follows a save")
        #expect(refreshed == 1, "Billing's row follows")
        #expect(BillingEmailsViewModel.savedMessage == "Billing emails updated")
    }

    @Test func doneWithoutAChangeOnlyCloses() async {
        let repository = FakeBillingRepository()
        let viewModel = await make(repository)
        await viewModel.save()
        #expect(repository.saves.isEmpty)
        #expect(viewModel.outcome == .closed, "Closed without a toast")
    }

    /// MS-141 review: an address typed but not added with Add goes in with Done, and a wrong one keeps the sheet open.
    @Test func doneAddsAnAddressStillInTheField() async {
        let repository = FakeBillingRepository()
        let viewModel = await make(repository)
        viewModel.newEmail = " Books@SmileDental.ca "
        await viewModel.save()
        #expect(repository.saves == [["books@smiledental.ca"]])
        #expect(viewModel.outcome == .saved)
    }

    @Test func doneStopsAtAWrongAddressInTheField() async {
        let repository = FakeBillingRepository()
        let viewModel = await make(repository)
        viewModel.newEmail = "books@smile"
        await viewModel.save()
        #expect(viewModel.emailError == "Enter a valid email")
        #expect(viewModel.outcome == nil, "The sheet stays open")
        #expect(repository.saves.isEmpty)
        viewModel.newEmail = "owner@smiledental.ca"
        await viewModel.save()
        #expect(viewModel.emailError == "This address is already on the list")
        #expect(viewModel.outcome == nil)
    }

    @Test func aRefusalStaysInTheSheet() async {
        let repository = FakeBillingRepository()
        let viewModel = await make(repository)
        viewModel.newEmail = "books@smiledental.ca"
        viewModel.add()
        repository.saveFailure = AppError.validation(field: "books@smiledental.ca", message: "Enter a valid email")
        await viewModel.save()
        #expect(viewModel.emailError == "books@smiledental.ca: Enter a valid email")
        #expect(viewModel.outcome == nil)
        repository.saveFailure = AppError.network
        await viewModel.save()
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.")
        #expect(viewModel.extra == ["books@smiledental.ca"], "What was added is kept")
    }
}
