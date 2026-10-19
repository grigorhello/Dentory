import Foundation
import Testing
@testable import Dentory

@MainActor
struct ProductFormViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        mode: ProductFormViewModel.Mode = .create,
        repository: FakeProductFormRepository = FakeProductFormRepository(),
        locale: Locale = Locale(identifier: "en_US")
    ) -> ProductFormViewModel {
        let formatters = ClinicFormatters(
            currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
            locale: locale, clock: FixedClock(Session.demoNow)
        )
        return ProductFormViewModel(
            repository: repository, formatters: formatters, clinicID: Session.demo.clinicID, mode: mode
        )
    }

    @Test func aNewProductStartsEmptyAndCannotBeCreatedYet() async {
        let repository = FakeProductFormRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.title == "New product")
        #expect(viewModel.submitTitle == "Create product")
        #expect(viewModel.showsReceivingHint)
        #expect(!viewModel.canSubmit, "Disabled until a name and unit are entered")
        await viewModel.load()
        #expect(repository.categoryCalls == [Session.demo.clinicID])
        #expect(viewModel.categoryChoices.count == ProductCategory.demo.count + 1)
        #expect(viewModel.categoryTitle(.new) == "New category…")
        viewModel.name = "Articaine 4%"
        #expect(!viewModel.canSubmit)
        viewModel.unit = "cartridges"
        #expect(viewModel.canSubmit)
    }

    @Test func thePackSentenceFollowsTheFieldsLive() {
        let viewModel = make()
        viewModel.unit = "cartridges"
        #expect(viewModel.packQuestion == nil)
        #expect(viewModel.packSentence == nil)
        viewModel.packUnit = "box"
        #expect(viewModel.packQuestion == "How many cartridges in 1 box?")
        #expect(viewModel.packSentence == "Stock is counted in the smaller unit.")
        viewModel.packSizeText = "50"
        #expect(
            viewModel.packSentence == "Receive in boxes, count and use in cartridges. 1 box adds 50 cartridges."
        )
        viewModel.packSizeText = "1"
        #expect(viewModel.packSentence == "Stock is counted in the smaller unit.", "A pack holds 2 or more")
    }

    @Test func pluralsOfTheUnitsAClinicTypes() {
        #expect(ProductFormViewModel.plural(of: "box") == "boxes")
        #expect(ProductFormViewModel.plural(of: "bottle") == "bottles")
        #expect(ProductFormViewModel.plural(of: "packs") == "packs")
        #expect(ProductFormViewModel.plural(of: "pouch") == "pouches")
    }

    @Test func createSendsTheTrimmedDraftAndReportsTheNewID() async {
        let repository = FakeProductFormRepository()
        let viewModel = make(repository: repository)
        await viewModel.load()
        viewModel.name = " Articaine 4% "
        viewModel.category = .existing(ProductCategory.demo[0])
        viewModel.unit = "cartridges"
        viewModel.packUnit = "box"
        viewModel.packSizeText = "50"
        viewModel.minimumText = "10"
        viewModel.targetText = "40"
        viewModel.supplier = "Patterson"
        await viewModel.save()
        let draft = repository.creates.first
        #expect(draft?.name == "Articaine 4%")
        #expect(draft?.categoryID == ProductCategory.demo[0].id)
        #expect(draft?.unit == "cartridges")
        #expect(draft?.packUnit == "box" && draft?.packSize == 50)
        #expect(draft?.tracking == .countable)
        #expect(draft?.minimum == 10 && draft?.target == 40)
        #expect(draft?.supplier == "Patterson" && draft?.location == nil)
        #expect(viewModel.outcome == .created(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1") ?? UUID()))
    }

    @Test func aNewCategoryIsCreatedFirstAndUsed() async {
        let repository = FakeProductFormRepository()
        let viewModel = make(repository: repository)
        viewModel.name = "Bracket kit"
        viewModel.unit = "kits"
        viewModel.category = .new
        #expect(viewModel.isNamingNewCategory)
        await viewModel.save()
        #expect(viewModel.categoryError == "Enter a category name")
        #expect(repository.creates.isEmpty)
        viewModel.newCategoryName = " Orthodontics "
        await viewModel.save()
        #expect(repository.findOrCreateCalls == ["Orthodontics"])
        #expect(repository.creates.first?.categoryID == UUID(uuidString: "00000000-0000-4000-8000-0000000000f2"))
    }

    @Test func theRulesHoldBeforeAnythingIsSent() async {
        let repository = FakeProductFormRepository()
        let viewModel = make(repository: repository)
        viewModel.name = "Gauze"
        viewModel.unit = "packs"
        viewModel.packUnit = "case"
        viewModel.packSizeText = "1"
        viewModel.minimumText = "10"
        viewModel.targetText = "5"
        await viewModel.save()
        #expect(viewModel.packSizeError == "Enter how many packs make 1 case, 2 or more")
        #expect(viewModel.targetError == "Target must be at least the minimum")
        #expect(repository.creates.isEmpty)
        viewModel.packSizeText = "20"
        #expect(viewModel.packSizeError == nil, "Typing clears the field's error")
        viewModel.targetText = "30"
        #expect(viewModel.targetError == nil)
        await viewModel.save()
        #expect(repository.creates.count == 1)
    }

    @Test func editStartsFromTheProductAndSavesChanges() async {
        let repository = FakeProductFormRepository()
        let product = ProductDetail.fixture(quantity: 0, unopened: 0)
        let viewModel = make(mode: .edit(product), repository: repository)
        #expect(viewModel.title == "Edit product")
        #expect(viewModel.submitTitle == "Save changes")
        #expect(!viewModel.showsReceivingHint)
        #expect(viewModel.name == "Septocaine 4% 1:100,000")
        #expect(viewModel.unit == "cartridges" && viewModel.packUnit == "box" && viewModel.packSizeText == "50")
        #expect(viewModel.minimumText == "20" && viewModel.targetText == "60")
        await viewModel.load()
        viewModel.minimumText = "25"
        await viewModel.save()
        #expect(repository.updates.first?.id == product.id)
        #expect(repository.updates.first?.draft.minimum == 25)
        #expect(viewModel.outcome == .saved)
    }

    @Test func theTrackingSwitchIsBlockedWhileStockIsHeld() {
        let viewModel = make(mode: .edit(ProductDetail.fixture(quantity: 54)))
        viewModel.setMultiUse(true)
        #expect(!viewModel.isMultiUse)
        #expect(viewModel.trackingError == "Set stock to 0 before changing how it is tracked.")
        let empty = make(mode: .edit(ProductDetail.fixture(quantity: 0, unopened: 0)))
        empty.setMultiUse(true)
        #expect(empty.isMultiUse && empty.trackingError == nil)
    }

    @Test func aRefusedSaveLandsOnItsFieldOrAsAToast() async {
        let repository = FakeProductFormRepository()
        repository.updateResult = .failure(
            AppError.validation(field: nil, message: "Set stock to 0 before changing how it is tracked.")
        )
        let viewModel = make(mode: .edit(ProductDetail.fixture()), repository: repository)
        await viewModel.save()
        #expect(viewModel.trackingError == "Set stock to 0 before changing how it is tracked.")
        #expect(viewModel.outcome == nil)
        repository.updateResult = .failure(AppError.readOnly)
        await viewModel.save()
        #expect(viewModel.generalError == .readOnly)
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }

    @Test func quantitiesParseAsTypedInTheClinicsLocale() {
        let english = Locale(identifier: "en_US")
        let french = Locale(identifier: "fr_CA")
        #expect(ProductFormViewModel.quantity(from: " 20 ", locale: english) == 20)
        #expect(ProductFormViewModel.quantity(from: "1,000.5", locale: english) == Decimal(string: "1000.5"))
        #expect(ProductFormViewModel.quantity(from: "1 000,5", locale: french) == Decimal(string: "1000.5"))
        #expect(ProductFormViewModel.quantity(from: "2,5", locale: french) == Decimal(string: "2.5"))
        #expect(ProductFormViewModel.quantity(from: "20.5", locale: french) == Decimal(string: "20.5"))
        #expect(ProductFormViewModel.quantity(from: "", locale: english) == nil)
        #expect(ProductFormViewModel.quantity(from: "ten", locale: english) == nil)
        #expect(ProductFormViewModel.quantity(from: "12abc", locale: english) == nil)
        #expect(ProductFormViewModel.plainText(1000, locale: english) == "1000")
        #expect(ProductFormViewModel.plainText(Decimal(string: "20.5") ?? 0, locale: french) == "20,5")
    }

    @Test(arguments: ["en_US", "fr_CA"])
    func editKeepsLevelsOfAThousandOrMore(localeID: String) async {
        let repository = FakeProductFormRepository()
        let product = ProductDetail.fixture(quantity: 0, unopened: 0, minimum: 1000, target: 2500)
        let viewModel = make(mode: .edit(product), repository: repository, locale: Locale(identifier: localeID))
        #expect(viewModel.minimumText == "1000" && viewModel.targetText == "2500", "No digit grouping in the fields")
        viewModel.name = "Patient bib"
        await viewModel.save()
        #expect(repository.updates.first?.draft.minimum == 1000)
        #expect(repository.updates.first?.draft.target == 2500)
    }
}
