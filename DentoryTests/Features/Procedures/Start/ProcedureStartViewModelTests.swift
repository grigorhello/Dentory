import Foundation
import Testing
@testable import Dentory

/// Adjust, then start (f13): the supplies, their warnings, Take new, Add item and Start.
struct ProcedureStartViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let rootCanal = ProcedureTemplateDetail.demo[0]

    private func make(_ repository: FakeProcedureStartRepository = FakeProcedureStartRepository()) async
        -> ProcedureStartViewModel {
        let viewModel = ProcedureStartViewModel(
            repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            templateID: rootCanal.id
        )
        await viewModel.load()
        return viewModel
    }

    private func id(of name: String) -> UUID {
        rootCanal.items.first { $0.name == name }?.id ?? UUID()
    }

    @Test func aTemplateOpensWithItsSuppliesAndBottles() async {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.name == "Root canal")
        #expect(viewModel.supplies.map(\.item.name) == [
            "Septocaine 4% 1:100,000", "Needle 27g short", "Nitrile gloves M", "Rubber dam latex-free",
            "Endo file kit #15-40", "Gutta percha F2", "Paper points", "Suction tips"
        ])
        #expect(viewModel.supplies.map(\.quantity) == [2, 1, 2, 1, 1, 1, 1, 1])
        #expect(viewModel.bottles.map(\.item.name) == [
            "Topical anesthetic gel", "Sodium hypochlorite", "Root canal sealer", "Surface disinfectant"
        ])
        #expect(viewModel.summary == "12 supplies · 1 not available. Add or remove items before you start.")
        #expect(viewModel.startTitle == "Start procedure · 10 items")
        #expect(viewModel.canStart)
    }

    @Test func aRowWarnsOnlyWhenStockRunsOutOrIsShort() async {
        let viewModel = await make()
        let rows = Dictionary(uniqueKeysWithValues: viewModel.supplies.map { ($0.item.name, $0) })
        #expect(rows["Rubber dam latex-free"].flatMap(viewModel.warning(for:))
            == .init(text: "Not available · 0 in stock", tone: .danger))
        #expect(rows["Endo file kit #15-40"].flatMap(viewModel.warning(for:))
            == .init(text: "0 will remain", tone: .warning))
        #expect(rows["Septocaine 4% 1:100,000"].flatMap(viewModel.warning(for:)) == nil)
        viewModel[quantityOf: id(of: "Rubber dam latex-free")] = 0
        #expect(viewModel.supplies.first { $0.item.name == "Rubber dam latex-free" }.flatMap(viewModel.warning(for:))
            == nil, "Nothing taken, nothing short")
        #expect(viewModel.summary == "12 supplies · 1 will reach 0. Add or remove items before you start.")
    }

    @Test func theSteppersChangeTheCountAndNeverGoBelowZero() async {
        let viewModel = await make()
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        viewModel[quantityOf: septocaine] = 3
        #expect(viewModel[quantityOf: septocaine] == 3)
        #expect(viewModel.startTitle == "Start procedure · 11 items")
        viewModel[quantityOf: septocaine] = -1
        #expect(viewModel[quantityOf: septocaine] == 0)
    }

    @Test func removingARowTakesItOffThisProcedure() async {
        let viewModel = await make()
        viewModel.remove(id(of: "Rubber dam latex-free"))
        #expect(viewModel.supplies.count == 7)
        #expect(viewModel.summary == "11 supplies · 1 will reach 0. Add or remove items before you start.")
        #expect(viewModel.startTitle == "Start procedure · 9 items")
    }

    @Test func takeNewCountsOneItemAndSaysWhatIsLeft() async {
        let viewModel = await make()
        let disinfectant = id(of: "Surface disinfectant")
        viewModel.toggleTakeNew(disinfectant)
        #expect(viewModel.takenNew.map(\.item.name) == ["Surface disinfectant"])
        #expect(viewModel.startTitle == "Start procedure · 11 items")
        let bottle = try? #require(viewModel.bottles.first { $0.id == disinfectant })
        #expect(bottle.map(viewModel.line(for:)) == "Will take 1 from stock · 0 unopened left")
        viewModel.toggleTakeNew(disinfectant)
        #expect(viewModel.takenNew.isEmpty, "Tapping again removes it")
        #expect(bottle.map { viewModel.line(for: .init(item: $0.item)) } == "2 open · 1 in stock")
    }

    @Test func nothingUnopenedMeansOutOfStock() async {
        let viewModel = await make()
        viewModel.toggleTakeNew(id(of: "Root canal sealer"))
        #expect(viewModel.takenNew.isEmpty)
        #expect(viewModel.message == .init(title: "Out of stock", detail: "Root canal sealer"))
        viewModel.clearMessage()
        viewModel.explainTakeNew()
        #expect(viewModel.message?.title == "Opened a new one?")
    }

    @Test func addItemOffersTheOtherCountableProductsAndAppendsOne() async {
        let repository = FakeProcedureStartRepository()
        let viewModel = await make(repository)
        viewModel.openAddItem()
        #expect(viewModel.sheet == .addItem)
        await viewModel.loadProducts()
        let offered = viewModel.addableProducts.map(\.name)
        #expect(!offered.contains("Septocaine 4% 1:100,000"), "Already on the list")
        #expect(!offered.contains("Composite A2"), "Multi-use products come from the template")
        #expect(offered.contains("Gauze"))
        viewModel.searchText = "gau"
        let gauze = try? #require(viewModel.addableProducts.first)
        #expect(gauze?.name == "Gauze")
        #expect(gauze.map(viewModel.addCaption(for:)) == "8 packs in stock")
        if let gauze { viewModel.add(gauze) }
        #expect(viewModel.sheet == nil)
        #expect(viewModel.supplies.last?.item.name == "Gauze")
        #expect(viewModel.supplies.last?.quantity == 1)
        #expect(viewModel.startTitle == "Start procedure · 11 items")
    }

    @Test func startSendsEverySupplyAndTheBottlesTakenNew() async {
        let repository = FakeProcedureStartRepository()
        let viewModel = await make(repository)
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        viewModel[quantityOf: septocaine] = 3
        viewModel.toggleTakeNew(id(of: "Surface disinfectant"))
        await viewModel.start()
        let request = try? #require(repository.starts.first)
        #expect(request?.clinicID == Session.demo.clinicID)
        #expect(request?.templateID == rootCanal.id)
        #expect(request?.name == "Root canal")
        #expect(request?.lines.count == 12, "Eight supplies and the four multi-use products")
        #expect(request?.lines.first == ProcedureStartLine(productID: septocaine, quantity: 3))
        #expect(request?.lines.suffix(4).allSatisfy { $0.quantity == 0 } == true, "An open bottle changes nothing")
        #expect(request?.takeNew == [id(of: "Surface disinfectant")])
        #expect(viewModel.started == .init(title: "Root canal started", detail: "12 items deducted"))
    }

    @Test func aRefusedStartStaysOnTheScreen() async {
        let repository = FakeProcedureStartRepository()
        repository.startResult = .failure(AppError.readOnly)
        let viewModel = await make(repository)
        await viewModel.start()
        #expect(viewModel.started == nil)
        #expect(viewModel.generalError == .readOnly)
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil)
    }

    @Test func aTemplateWithEverythingInStockSaysSo() async {
        let viewModel = await make(FakeProcedureStartRepository(template: ProcedureTemplateDetail.demo[1]))
        #expect(viewModel.summary == "7 supplies · all in stock. Add or remove items before you start.")
    }

    @Test func aMissingTemplateShowsTheError() async {
        let repository = FakeProcedureStartRepository()
        repository.templateResult = .failure(AppError.notFound)
        let viewModel = await make(repository)
        #expect(viewModel.state == .failed(.notFound))
        #expect(viewModel.canStart == false)
    }

    @Test func theCountsReadInTheSingularToo() {
        #expect(ProcedureStartViewModel.itemsDeducted(1) == "1 item deducted")
        #expect(ProcedureStartViewModel.itemsDeducted(10) == "10 items deducted")
    }
}
