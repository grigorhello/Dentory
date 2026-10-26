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
        locale: Locale = Locale(identifier: "en_US"),
        analytics: SpyAnalytics = SpyAnalytics()
    ) -> ProductFormViewModel {
        let formatters = ClinicFormatters(
            currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
            locale: locale, clock: FixedClock(Session.demoNow)
        )
        return ProductFormViewModel(
            repository: repository, formatters: formatters, clinicID: Session.demo.clinicID, mode: mode,
            analytics: analytics
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

    @Test func createSendsTheTrimmedDraftAndReportsTheNewID() async {
        let repository = FakeProductFormRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(repository: repository, analytics: analytics)
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
        #expect(analytics.events == [.productCreated], "inv.newProduct, without the name (MS-147)")
    }

    /// New on Choose product (Receive manually, MS-127): the name starts as the search, and the button creates the
    /// product and chooses it.
    @Test func newFromChooseProductStartsFromTheSearchAndCreatesAndSelects() async {
        let repository = FakeProductFormRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(
            mode: .createAndSelect(name: "  Articaine 4% "), repository: repository, analytics: analytics
        )
        #expect(viewModel.title == "New product")
        #expect(viewModel.submitTitle == "Create and select")
        #expect(viewModel.name == "Articaine 4%")
        #expect(viewModel.showsReceivingHint)
        #expect(!viewModel.canSubmit, "Still waits for the unit")
        viewModel.unit = "cartridges"
        await viewModel.save()
        #expect(repository.creates.map(\.name) == ["Articaine 4%"])
        #expect(viewModel.outcome == .created(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1") ?? UUID()))
        #expect(analytics.events == [.productCreated])
    }

    /// Add new or No, create new on an invoice line (Review invoice, MS-130): the notice quotes the line, the name and
    /// unit start as suggested, and the button creates the product for the line.
    @Test func newFromAnInvoiceLineStartsAsTheLineSuggestsAndUsesTheProductForIt() async {
        let repository = FakeProductFormRepository()
        let analytics = SpyAnalytics()
        let viewModel = make(
            mode: .invoiceLine(raw: "TEMPBOND NE 1PK", name: "Tempbond NE", unit: "packs"), repository: repository,
            analytics: analytics
        )
        #expect(viewModel.title == "New product")
        #expect(viewModel.submitTitle == "Create and use for this line")
        #expect(viewModel.invoiceNotice
            == "From invoice: TEMPBOND NE 1PK. Name and unit are suggested. Check them and add the rest.")
        #expect(viewModel.name == "Tempbond NE")
        #expect(viewModel.unit == "packs")
        #expect(viewModel.packUnit.isEmpty)
        #expect(viewModel.showsReceivingHint)
        #expect(viewModel.canSubmit, "Name and unit are there already")
        viewModel.name = "Temp-Bond NE"
        await viewModel.save()
        #expect(repository.creates.map(\.name) == ["Temp-Bond NE"])
        #expect(repository.creates.map(\.unit) == ["packs"])
        #expect(viewModel.outcome == .created(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1") ?? UUID()))
        #expect(analytics.events == [.productCreated], "Counted as the New product sheet's inv.newProduct")
    }

    @Test func onlyAnInvoiceLineShowsTheNotice() {
        #expect(make().invoiceNotice == nil)
        #expect(make(mode: .createAndSelect(name: "Gauze")).invoiceNotice == nil)
        #expect(make(mode: .invoiceLine(raw: "GAUZE 2X2.", name: "", unit: "")).invoiceNotice
            == "From invoice: GAUZE 2X2. Name and unit are suggested. Check them and add the rest.",
            "One full stop after the line")
        #expect(!make(mode: .invoiceLine(raw: "GAUZE", name: " ", unit: "")).canSubmit, "No name suggested")
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
        let analytics = SpyAnalytics()
        let product = ProductDetail.fixture(quantity: 0, unopened: 0)
        let viewModel = make(mode: .edit(product), repository: repository, analytics: analytics)
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
        #expect(analytics.events.isEmpty, "Only a new product is tracked")
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

    @Test func negativeStockOrAnOpenBottleBlocksTheSwitchToo() {
        // MS-100 D9: -1 unopened plus 1 open bottle reads quantity 0, yet the product holds stock.
        let product = ProductDetail.fixture(tracking: .multiUse, quantity: 0, unopened: -1, openCount: 1)
        let bottle = make(mode: .edit(product))
        bottle.setMultiUse(false)
        #expect(bottle.isMultiUse)
        #expect(bottle.trackingError == "Set stock to 0 before changing how it is tracked.")
        let short = make(mode: .edit(ProductDetail.fixture(quantity: -2, unopened: -2)))
        short.setMultiUse(true)
        #expect(!short.isMultiUse)
        #expect(short.trackingError != nil)
    }

    @Test func thePackSizeReadsNativeDigitsAndWantsAWholeNumber() {
        let viewModel = make(locale: Locale(identifier: "ar_SA"))
        viewModel.unit = "cartridges"
        viewModel.packUnit = "box"
        viewModel.packSizeText = "٥٠"
        #expect(viewModel.packSize == 50)
        viewModel.packSizeText = "2.5"
        #expect(viewModel.packSize == nil)
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

    @Test(arguments: ["en_US", "fr_CA", "ar_SA"])
    func editKeepsLevelsOfAThousandOrMore(localeID: String) async {
        let locale = Locale(identifier: localeID)
        let repository = FakeProductFormRepository()
        let product = ProductDetail.fixture(quantity: 0, unopened: 0, minimum: 1000, target: 2500)
        let viewModel = make(mode: .edit(product), repository: repository, locale: locale)
        #expect(!viewModel.minimumText.contains(locale.groupingSeparator ?? ","), "No digit grouping in the fields")
        #expect(QuantityText.parse(viewModel.minimumText, locale: locale) == 1000)
        viewModel.name = "Patient bib"
        await viewModel.save()
        #expect(repository.updates.first?.draft.minimum == 1000)
        #expect(repository.updates.first?.draft.target == 2500)
    }

    @Test func aLevelThatIsNotANumberIsRefusedNotSavedAsZero() async {
        let repository = FakeProductFormRepository()
        let viewModel = make(mode: .edit(ProductDetail.fixture()), repository: repository)
        viewModel.minimumText = "abc"
        viewModel.targetText = "1o"
        await viewModel.save()
        #expect(viewModel.minimumError == "Enter a number")
        #expect(viewModel.targetError == "Enter a number")
        #expect(repository.updates.isEmpty)
        viewModel.minimumText = "١٠"
        #expect(viewModel.minimumError == nil)
    }

    @Test func theCategoryStaysWhenTheListDidNotLoad() async {
        let repository = FakeProductFormRepository()
        repository.categoriesResult = .failure(AppError.network)
        let product = ProductDetail.fixture()
        let viewModel = make(mode: .edit(product), repository: repository)
        await viewModel.load()
        #expect(viewModel.category == nil && viewModel.generalError == .network)
        viewModel.clearGeneralError()
        viewModel.name = "Septocaine 4% 1:100,000 Gold"
        await viewModel.save()
        #expect(repository.updates.first?.draft.categoryID == product.categoryID)
        #expect(product.categoryID != nil, "The fixture carries a category")
    }
}
