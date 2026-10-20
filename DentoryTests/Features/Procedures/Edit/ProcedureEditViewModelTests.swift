import Foundation
import Testing
@testable import Dentory

/// Edit procedure (f15): the defaults, Add item, Save with its refusals, and Delete procedure.
struct ProcedureEditViewModelTests {
    private let rootCanal = ProcedureTemplateDetail.demo[0]

    private func make(
        _ repository: FakeProcedureEditRepository = FakeProcedureEditRepository(), isNew: Bool = false
    ) async -> ProcedureEditViewModel {
        let viewModel = ProcedureEditViewModel(
            repository: repository, clinicID: Session.demo.clinicID, templateID: isNew ? nil : rootCanal.id
        )
        await viewModel.load()
        return viewModel
    }

    private func id(of name: String) -> UUID {
        (rootCanal.items.map(\.id) + (ProductSummary.demo + DemoSupplies.extraProducts).map(\.id))
            .first { id in
                rootCanal.items.first { $0.id == id }?.name == name
                    || (ProductSummary.demo + DemoSupplies.extraProducts).first { $0.id == id }?.name == name
            } ?? UUID()
    }

    private func product(_ name: String) throws -> ProductSummary {
        try #require((ProductSummary.demo + DemoSupplies.extraProducts).first { $0.name == name })
    }

    @Test func aTemplateOpensWithItsNameAndDefaults() async {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.title == "Edit procedure")
        #expect(viewModel.name == "Root canal")
        #expect(viewModel.items.map(\.name) == rootCanal.items.map(\.name))
        #expect(viewModel.items.map(\.quantity) == [2, 1, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0])
        #expect(viewModel.items.suffix(4).allSatisfy { $0.tracking == .multiUse })
        #expect(viewModel.canSave)
    }

    @Test func aNewProcedureOpensEmptyWithoutAServerRead() async {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository, isNew: true)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.title == "New procedure")
        #expect(viewModel.name.isEmpty)
        #expect(viewModel.items.isEmpty)
        #expect(repository.templateCalls == 0)
    }

    @Test func untilTheTemplateIsLoadedSaveIsOff() {
        let viewModel = ProcedureEditViewModel(
            repository: FakeProcedureEditRepository(), clinicID: Session.demo.clinicID, templateID: rootCanal.id
        )
        #expect(viewModel.state == .loading)
        #expect(!viewModel.canSave)
    }

    @Test func openingAgainKeepsWhatTheAdminChanged() async {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository)
        viewModel.name = "Root canal, molar"
        await viewModel.load()
        #expect(viewModel.name == "Root canal, molar")
        #expect(repository.templateCalls == 1)
    }

    @Test func aMissingTemplateSaysSo() async {
        let repository = FakeProcedureEditRepository()
        repository.templateResult = .failure(AppError.notFound)
        let viewModel = await make(repository)
        #expect(viewModel.state == .failed(.notFound))
        #expect(!viewModel.canSave)
    }

    @Test func aCountableDefaultNeverGoesBelowOne() async {
        let viewModel = await make()
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        viewModel[quantityOf: septocaine] = 3
        #expect(viewModel[quantityOf: septocaine] == 3)
        viewModel[quantityOf: septocaine] = 0
        #expect(viewModel[quantityOf: septocaine] == 1)
        let disinfectant = id(of: "Surface disinfectant")
        viewModel[quantityOf: disinfectant] = 2
        #expect(viewModel[quantityOf: disinfectant] == 0, "A multi-use supply keeps 0")
    }

    @Test func theXTakesASupplyOffTheTemplate() async {
        let viewModel = await make()
        viewModel.remove(id(of: "Rubber dam latex-free"))
        viewModel.remove(id(of: "Root canal sealer"))
        #expect(viewModel.items.count == 10)
        #expect(!viewModel.items.contains { $0.name == "Rubber dam latex-free" || $0.name == "Root canal sealer" })
    }

    @Test func addItemOffersEveryProductNotListedWithItsCategory() async throws {
        let viewModel = await make()
        viewModel.openAddItem()
        #expect(viewModel.sheet == .addItem)
        #expect(viewModel.addItemEmptyText.isEmpty, "Nothing to say while the products load")
        await viewModel.loadProducts()
        let names = viewModel.addableProducts.map(\.name)
        #expect(names.count == 11)
        #expect(names.contains("Gauze") && names.contains("Composite A2"))
        #expect(!names.contains("Septocaine 4% 1:100,000") && !names.contains("Surface disinfectant"))
        #expect(viewModel.addCaption(for: try product("Gauze")) == "Surgical")
        #expect(viewModel.addCaption(for: try product("Composite A2")) == "Restorative · multi-use")
        viewModel.searchText = "comp"
        #expect(viewModel.addableProducts.map(\.name) == ["Composite A2"])
        viewModel.searchText = "zzz"
        #expect(viewModel.addableProducts.isEmpty)
        #expect(viewModel.addItemEmptyText == "No products match.")
    }

    @Test func productsThatFailToLoadAreExplainedInTheSheet() async {
        let repository = FakeProcedureEditRepository()
        repository.productsResult = .failure(AppError.network)
        let viewModel = await make(repository)
        viewModel.openAddItem()
        await viewModel.loadProducts()
        #expect(viewModel.addItemEmptyText == "Couldn't load products. Close and reopen Add item to try again.")
        #expect(viewModel.generalError == nil, "No toast: it would sit behind the sheet")
    }

    @Test func addingAppendsACountableWithOneAndAMultiUseWithZero() async throws {
        let viewModel = await make()
        await viewModel.loadProducts()
        viewModel.openAddItem()
        viewModel.add(try product("Gauze"))
        #expect(viewModel.sheet == nil)
        viewModel.add(try product("Composite A2"))
        #expect(viewModel.items.suffix(2).map(\.name) == ["Gauze", "Composite A2"])
        #expect(viewModel.items.suffix(2).map(\.quantity) == [1, 0])
        viewModel.add(try product("Gauze"))
        #expect(viewModel.items.count == 14, "A product is listed once")
    }

    @Test func saveSendsTheNameAndTheDefaultsInScreenOrder() async throws {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository)
        viewModel.name = "  Root canal, molar "
        viewModel[quantityOf: id(of: "Septocaine 4% 1:100,000")] = 3
        viewModel.remove(id(of: "Rubber dam latex-free"))
        viewModel.add(try product("Gauze"))
        await viewModel.save()
        let request = try #require(repository.saves.first)
        #expect(request.templateID == rootCanal.id)
        #expect(request.clinicID == Session.demo.clinicID)
        #expect(request.name == "Root canal, molar")
        #expect(request.lines.map(\.productID) == viewModel.items.map(\.id))
        #expect(request.lines.map(\.defaultQuantity) == [3, 1, 2, 1, 1, 1, 1, 0, 0, 0, 0, 1])
        #expect(viewModel.outcome == .init(title: "Procedure saved", detail: "Root canal, molar · 12 default supplies"))
    }

    @Test func aNewProcedureWithoutANameIsSavedAsUntitled() async throws {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository, isNew: true)
        viewModel.name = "   "
        viewModel.add(try product("Gauze"))
        await viewModel.save()
        #expect(repository.saves.first?.templateID == nil)
        #expect(repository.saves.first?.name == "")
        #expect(viewModel.outcome == .init(title: "Procedure saved", detail: "Untitled procedure · 1 default supply"))
    }

    @Test func aTakenNameShowsUnderTheFieldUntilItChanges() async {
        let repository = FakeProcedureEditRepository()
        repository.saveError = AppError.validation(
            field: "name", message: "Another procedure is already called Filling."
        )
        let viewModel = await make(repository)
        viewModel.name = "filling"
        await viewModel.save()
        #expect(viewModel.nameError == "Another procedure is already called Filling.")
        #expect(viewModel.outcome == nil)
        #expect(viewModel.generalError == nil)
        viewModel.name = "Filling, deep"
        #expect(viewModel.nameError == nil)
    }

    @Test func aNameOfMoreThan120CharactersIsNotSent() async {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository)
        viewModel.name = String(repeating: "a", count: 121)
        await viewModel.save()
        #expect(viewModel.nameError == "Use 120 characters or fewer for the name.")
        #expect(repository.saves.isEmpty)
    }

    @Test func anotherRefusalIsAToastAndKeepsTheEdits() async {
        let repository = FakeProcedureEditRepository()
        repository.saveError = AppError.forbidden
        let viewModel = await make(repository)
        viewModel.remove(id(of: "Rubber dam latex-free"))
        await viewModel.save()
        #expect(viewModel.generalError == .forbidden)
        #expect(viewModel.outcome == nil)
        #expect(viewModel.items.count == 11)
        #expect(viewModel.canSave)
    }

    @Test func noConnectionReadsAsAFailedSave() async {
        let repository = FakeProcedureEditRepository()
        repository.saveError = AppError.network
        let viewModel = await make(repository)
        await viewModel.save()
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.")
    }

    @Test func deleteArchivesTheTemplateAndSaysSo() async {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository)
        viewModel.name = "Typed but not saved"
        viewModel.askToDelete()
        #expect(viewModel.sheet == .delete)
        #expect(viewModel.deleteTitle == "Delete Root canal?")
        #expect(viewModel.deleteMessage == "Past procedures keep their data.")
        await viewModel.delete()
        #expect(repository.archived == [rootCanal.id])
        #expect(viewModel.outcome == .init(title: "Procedure deleted", detail: "Root canal"))
        #expect(viewModel.sheet == nil)
    }

    @Test func keepClosesTheDeleteSheet() async {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository)
        viewModel.askToDelete()
        viewModel.keep()
        #expect(viewModel.sheet == nil)
        #expect(repository.archived.isEmpty)
    }

    @Test func aRefusedDeleteClosesTheSheetForTheToast() async {
        let repository = FakeProcedureEditRepository()
        repository.archiveError = AppError.readOnly
        let viewModel = await make(repository)
        viewModel.askToDelete()
        await viewModel.delete()
        #expect(viewModel.generalError == .readOnly)
        #expect(viewModel.outcome == nil)
        #expect(viewModel.sheet == nil)
    }

    @Test func aNewProcedureCannotBeDeleted() async {
        let repository = FakeProcedureEditRepository()
        let viewModel = await make(repository, isNew: true)
        await viewModel.delete()
        #expect(repository.archived.isEmpty)
        #expect(viewModel.outcome == nil)
    }
}
