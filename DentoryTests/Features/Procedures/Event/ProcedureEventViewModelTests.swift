import Foundation
import Testing
@testable import Dentory

/// A past procedure (f14): the record, Edit usage, Save changes, Discard and Cancel procedure.
struct ProcedureEventViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let rootCanal = ProcedureEventDetail.demo[0]

    private func make(
        _ repository: FakeProcedureEventRepository = FakeProcedureEventRepository(), startsEditing: Bool = false,
        analytics: SpyAnalytics = SpyAnalytics()
    ) async -> ProcedureEventViewModel {
        let viewModel = ProcedureEventViewModel(
            repository: repository, formatters: formatters, clinicID: Session.demo.clinicID, eventID: rootCanal.id,
            startsEditing: startsEditing, analytics: analytics
        )
        await viewModel.load()
        return viewModel
    }

    private func id(of name: String) -> UUID {
        rootCanal.items.first { $0.name == name }?.id ?? UUID()
    }

    private func item(_ name: String) throws -> ProcedureEventDetail.Item {
        try #require(rootCanal.items.first { $0.name == name })
    }

    @Test func aPastProcedureReadsAsRecorded() async throws {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.mode == .done)
        #expect(viewModel.title == "Root canal")
        #expect(viewModel.summary == "10 items deducted · Oct 1 · 3:14\u{202F}PM · Sarah")
        #expect(viewModel.cancelledText == nil)
        #expect(viewModel.usage(of: try item("Septocaine 4% 1:100,000")) == "2")
        #expect(viewModel.usage(of: try item("Surface disinfectant")) == "Used from open bottle")
        let opened = try item("Surface disinfectant").recorded(qty: 0, takenNew: true)
        #expect(viewModel.usage(of: opened) == "Opened a new bottle")
    }

    @Test func homesEditUsageOpensInEditing() async {
        let viewModel = await make(startsEditing: true)
        #expect(viewModel.mode == .editing)
        #expect(viewModel.supplies.map(\.quantity) == [2, 1, 2, 1, 1, 1, 1, 1])
        #expect(viewModel.canSave == false, "Nothing changed yet")
    }

    @Test func aChangedQuantityTurnsBlueWithWhatWasRecordedAndDiscardForgetsIt() async throws {
        let viewModel = await make()
        viewModel.startEditing()
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        viewModel[quantityOf: septocaine] = 3
        let supply = try #require(viewModel.supplies.first { $0.id == septocaine })
        #expect(viewModel.note(for: supply) == ProcedureLineNote(text: "Recorded 2"))
        #expect(viewModel.canSave)
        viewModel[quantityOf: septocaine] = 2
        #expect(viewModel.canSave == false, "Back to what was recorded")
        viewModel[quantityOf: septocaine] = 5
        viewModel.discard()
        #expect(viewModel.mode == .done)
        #expect(viewModel[quantityOf: septocaine] == 2)
        #expect(viewModel.hasChanges == false)
    }

    @Test func saveSendsTheUsageAndShowsTheRecordAsEdited() async throws {
        let repository = FakeProcedureEventRepository()
        repository.editResult = .success(.queued)
        let analytics = SpyAnalytics()
        let viewModel = await make(repository, analytics: analytics)
        viewModel.startEditing()
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        let gloves = id(of: "Nitrile gloves M")
        let disinfectant = id(of: "Surface disinfectant")
        viewModel[quantityOf: septocaine] = 3
        viewModel[quantityOf: gloves] = 1
        viewModel.toggleTakeNew(disinfectant)
        await viewModel.save()

        let edit = try #require(repository.edits.first)
        #expect(edit.eventID == rootCanal.id)
        #expect(edit.lines.count == 12, "Eight supplies and the four multi-use products")
        #expect(edit.lines.first == ProcedureStartLine(productID: septocaine, quantity: 3))
        #expect(edit.lines.contains(ProcedureStartLine(productID: gloves, quantity: 1)))
        #expect(edit.lines.suffix(4).allSatisfy { $0.quantity == 0 }, "A multi-use product is recorded at 0")
        #expect(edit.takeNew == [disinfectant])
        #expect(viewModel.message == .init(title: "Usage updated", detail: nil))
        #expect(viewModel.mode == .done)
        #expect(viewModel.summary == "11 items deducted · Oct 1 · 3:14\u{202F}PM · Sarah", "Queued: shown as edited")
        #expect(analytics.events == [.procedureUsageEdited(items: 3)], "Two quantities and a bottle (MS-147)")
    }

    @Test func anAppliedSaveReadsTheRecordAgain() async {
        let repository = FakeProcedureEventRepository()
        let viewModel = await make(repository)
        viewModel.startEditing()
        viewModel[quantityOf: id(of: "Paper points")] = 2
        await viewModel.save()
        #expect(repository.eventCalls == 2)
        #expect(viewModel.mode == .done)
    }

    @Test func aRefusedSaveKeepsTheEdit() async {
        let repository = FakeProcedureEventRepository()
        repository.editResult = .failure(AppError.readOnly)
        let viewModel = await make(repository)
        viewModel.startEditing()
        let septocaine = id(of: "Septocaine 4% 1:100,000")
        viewModel[quantityOf: septocaine] = 3
        await viewModel.save()
        #expect(viewModel.generalError == .readOnly)
        #expect(viewModel.mode == .editing)
        #expect(viewModel[quantityOf: septocaine] == 3)
        #expect(viewModel.message == nil)
    }

    @Test func theXTakesASupplyOffTheRecord() async throws {
        let repository = FakeProcedureEventRepository()
        let viewModel = await make(repository)
        viewModel.startEditing()
        let paperPoints = id(of: "Paper points")
        viewModel.remove(paperPoints)
        #expect(viewModel.canSave)
        await viewModel.save()
        let edit = try #require(repository.edits.first)
        #expect(edit.lines.contains { $0.productID == paperPoints } == false, "Not listed: returned to stock")
    }

    @Test func addItemAddsACountableWithOneAndAMultiUseTakenNew() async throws {
        let viewModel = await make()
        viewModel.startEditing()
        viewModel.openAddItem()
        #expect(viewModel.sheet == .addItem)
        await viewModel.loadProducts()
        let offered = viewModel.addableProducts.map(\.name)
        #expect(!offered.contains("Septocaine 4% 1:100,000"), "Already recorded")
        #expect(!offered.contains("Surface disinfectant"), "Already under Opened a new one?")
        let gauze = try #require(viewModel.addableProducts.first { $0.name == "Gauze" })
        viewModel.add(gauze)
        #expect(viewModel.sheet == nil)
        let added = try #require(viewModel.supplies.last)
        #expect(added.item.name == "Gauze")
        #expect(added.quantity == 1)
        #expect(viewModel.note(for: added) == ProcedureLineNote(text: "Recorded 0"))

        viewModel.openAddItem()
        let composite = try #require(viewModel.addableProducts.first { $0.name == "Composite A2" })
        viewModel.add(composite)
        #expect(viewModel.takenNew.map(\.item.name) == ["Composite A2"])
        #expect(!viewModel.bottleLines.contains { $0.id == composite.id }, "Listed with the supplies only")
        viewModel.toggleTakeNew(composite.id)
        #expect(viewModel.bottles.contains { $0.id == composite.id } == false, "Off removes what Add item brought")
    }

    @Test func aMultiUseProductWithNothingUnopenedIsNotAdded() async throws {
        let viewModel = await make()
        viewModel.startEditing()
        viewModel.openAddItem()
        await viewModel.loadProducts()
        let bonding = try #require(viewModel.addableProducts.first { $0.name == "Bonding agent" })
        viewModel.add(bonding)
        #expect(viewModel.addCaption(for: bonding) == "Out of stock", "Said on the row, inside the sheet")
        #expect(viewModel.addCaptionTone(for: bonding) == .danger)
        #expect(viewModel.sheet == .addItem, "The sheet stays open to pick another")
        #expect(viewModel.bottles.contains { $0.id == bonding.id } == false)
    }

    @Test func takeNewSaysWhatSaveWillDoToEachBottle() async throws {
        let disinfectant = try item("Surface disinfectant")
        let sealer = try item("Root canal sealer")
        let recorded = rootCanal.with(items: rootCanal.items.map {
            $0.id == sealer.id ? $0.recorded(qty: 0, takenNew: true) : $0
        })
        let viewModel = await make(FakeProcedureEventRepository(event: recorded))
        viewModel.startEditing()
        func line(_ id: UUID) -> String? {
            viewModel.bottleLines.first { $0.id == id }?.line
        }
        #expect(line(disinfectant.id) == "2 open · 1 in stock")
        #expect(line(sealer.id) == "Opened a new bottle")
        viewModel.toggleTakeNew(disinfectant.id)
        #expect(line(disinfectant.id) == "Will take 1 from stock · 0 unopened left")
        viewModel.toggleTakeNew(sealer.id)
        #expect(line(sealer.id) == "Goes back to stock")
        #expect(viewModel.message == nil, "A bottle opened for this procedure can go back with nothing unopened")
    }

    @Test func nothingUnopenedMeansOutOfStock() async {
        let viewModel = await make()
        viewModel.startEditing()
        viewModel.toggleTakeNew(id(of: "Root canal sealer"))
        #expect(viewModel.takenNew.isEmpty)
        #expect(viewModel.message == .init(title: "Out of stock", detail: "Root canal sealer"))
        viewModel.clearMessage()
        viewModel.explainTakeNew()
        #expect(viewModel.message?.title == "Opened a new one?")
    }

    @Test func cancellingNeedsANoteAndGoesBackWithTheItemsReturned() async {
        let repository = FakeProcedureEventRepository()
        let analytics = SpyAnalytics()
        let viewModel = await make(repository, analytics: analytics)
        #expect(viewModel.cancelTitle == "Cancel Root canal?")
        #expect(viewModel.cancelWarning == "10 items will be returned to inventory. Stock levels update immediately.")
        viewModel.askToCancel()
        #expect(viewModel.sheet == .cancel)
        #expect(viewModel.canConfirmCancel == false)
        viewModel.cancelNote = "   "
        #expect(viewModel.canConfirmCancel == false, "Spaces are not a note")
        viewModel.cancelNote = " Logged by mistake "
        #expect(viewModel.canConfirmCancel)
        await viewModel.cancelProcedure()
        #expect(repository.cancelNotes == ["Logged by mistake"])
        #expect(viewModel.sheet == nil)
        #expect(viewModel.finished == .init(title: "Root canal cancelled", detail: "10 items returned"))
        #expect(analytics.events == [.procedureCancelled])
        #expect(analytics.events.first?.payload.isEmpty == true, "The note never leaves the app (MS-147)")
    }

    @Test func aRefusedCancelKeepsTheSheetAndSaysWhy() async {
        let repository = FakeProcedureEventRepository()
        repository.cancelResult = .failure(AppError.validation(field: nil, message: "Already cancelled"))
        let viewModel = await make(repository)
        viewModel.askToCancel()
        viewModel.cancelNote = "Logged by mistake"
        await viewModel.cancelProcedure()
        #expect(viewModel.sheet == .cancel, "A toast would sit behind the sheet")
        #expect(viewModel.cancelError == "Already cancelled")
        #expect(viewModel.cancelNote == "Logged by mistake")
        #expect(viewModel.finished == nil)
        viewModel.keep()
        viewModel.askToCancel()
        #expect(viewModel.cancelError == nil, "Asked again, the sheet starts fresh")
    }

    @Test func aCancelledProcedureIsReadOnly() async {
        let cancelled = rootCanal.cancelled(at: Session.demoNow, by: "Sarah Mitchell", note: "Logged by mistake")
        let viewModel = await make(FakeProcedureEventRepository(event: cancelled))
        let when = formatters.dateTime(Session.demoNow)
        #expect(viewModel.cancelledText == "Cancelled · \(when) · Sarah: Logged by mistake")
        viewModel.startEditing()
        #expect(viewModel.mode == .done)
    }

    @Test func aMissingProcedureShowsTheErrorButAFailedReloadKeepsTheRecord() async {
        let missing = FakeProcedureEventRepository()
        missing.eventResult = .failure(AppError.notFound)
        #expect(await make(missing).state == .failed(.notFound))

        let repository = FakeProcedureEventRepository()
        let viewModel = await make(repository)
        repository.eventResult = .failure(AppError.network)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.detail == rootCanal)
    }

    @Test func theCountsReadInTheSingularToo() {
        #expect(ProcedureEventViewModel.items(1) == "1 item")
        #expect(ProcedureEventViewModel.itemsReturned(10) == "10 items returned")
    }
}
