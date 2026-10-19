import Foundation
import Testing
@testable import Dentory

@MainActor
struct AdjustInventoryViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        detail: ProductDetail = .demoSeptocaine(),
        repository: FakeProductDetailRepository = FakeProductDetailRepository()
    ) -> AdjustInventoryViewModel {
        AdjustInventoryViewModel(detail: detail, repository: repository, formatters: formatters)
    }

    @Test func opensOnTheEstimateWithTheCaptionAndNoReason() {
        let viewModel = make()
        #expect(viewModel.quantityText == "54")
        #expect(viewModel.estimate == 54)
        #expect(viewModel.unit == "cartridges")
        #expect(viewModel.quantityLabel == "Actual quantity")
        #expect(viewModel.caption == "System estimate 54 cartridges. A reason is recorded in history.")
        #expect(viewModel.reason == nil)
        #expect(!viewModel.needsNote)
        #expect(!viewModel.canSave, "Nothing changed yet")
    }

    @Test func aMultiUseProductCountsUnopenedOnly() {
        let detail = ProductDetail.fixture(tracking: .multiUse, quantity: 3, unopened: 1, openCount: 2)
        let viewModel = make(detail: detail)
        #expect(viewModel.isMultiUse)
        #expect(viewModel.estimate == 1, "Open bottles are not counted (MS-100 G3)")
        #expect(viewModel.quantityText == "1")
        #expect(viewModel.quantityLabel == "Unopened")
        #expect(viewModel.caption == "System estimate 1 unopened. A reason is recorded in history.")
    }

    @Test func saveWaitsForADifferentQuantityAndAReason() {
        let viewModel = make()
        viewModel.reason = .damaged
        #expect(!viewModel.canSave, "The quantity still equals the estimate")
        viewModel.quantityText = "52"
        #expect(viewModel.canSave)
        viewModel.reason = nil
        #expect(!viewModel.canSave, "No reason")
        viewModel.reason = .damaged
        viewModel.quantityText = ""
        #expect(!viewModel.canSave, "No quantity")
        viewModel.quantityText = "abc"
        #expect(viewModel.actualQuantity == nil)
        #expect(!viewModel.canSave, "Not a number")
        viewModel.quantityText = "-1"
        #expect(viewModel.quantityError == "A quantity cannot be negative.")
        #expect(!viewModel.canSave)
        viewModel.quantityText = "2.5"
        #expect(viewModel.actualQuantity == Decimal(string: "2.5"))
        #expect(viewModel.quantityError == nil)
        #expect(viewModel.canSave, "Decimals are quantities too (2.5 bags)")
    }

    @Test func otherNeedsANote() {
        let viewModel = make()
        viewModel.quantityText = "50"
        viewModel.reason = .other
        #expect(viewModel.needsNote)
        #expect(!viewModel.canSave, "Other says nothing on its own")
        viewModel.note = "   "
        #expect(!viewModel.canSave, "Blank is no note")
        viewModel.note = "Gave 4 to the other practice"
        #expect(viewModel.canSave)
        viewModel.reason = .waste
        #expect(!viewModel.needsNote)
        #expect(viewModel.canSave)
    }

    @Test func theReasonsAreThePRDListInOrder() {
        #expect(AdjustInventoryViewModel.reasons.map(\.label) == [
            "Physical count", "Expired", "Damaged", "Waste", "Missing", "Returned", "Data correction", "Other"
        ])
        #expect(AdjustmentReason.other.requiresNote)
        #expect(!AdjustmentReason.physicalCount.requiresNote)
    }

    @Test func savingCallsStockAdjustAndReportsBeforeAfterAndTheActionID() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        viewModel.quantityText = "52"
        viewModel.reason = .damaged
        viewModel.note = ""
        await viewModel.save()
        #expect(repository.adjusts == [.init(
            productID: ProductSummary.demo[0].id, actualQuantity: 52, reason: .damaged, note: nil
        )])
        #expect(viewModel.saved == .init(
            actionID: UUID(uuidString: "00000000-0000-4000-8000-0000000000ac"), before: 54, after: 52
        ))
        #expect(viewModel.generalError == nil)
    }

    @Test func theNoteOfOtherTravelsTrimmed() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        viewModel.quantityText = "50"
        viewModel.reason = .other
        viewModel.note = "  Gave 4 to the other practice \n"
        await viewModel.save()
        #expect(repository.adjusts.first?.note == "Gave 4 to the other practice")
    }

    @Test func aQueuedWriteSavesWithoutAnActionID() async {
        let repository = FakeProductDetailRepository()
        repository.adjustResult = .success(.queued)
        let viewModel = make(repository: repository)
        viewModel.quantityText = "52"
        viewModel.reason = .missing
        await viewModel.save()
        #expect(viewModel.saved == .init(actionID: nil, before: 54, after: 52), "Offline: nothing to undo yet")
    }

    @Test func aRefusalStaysInTheSheetWithTheInput() async {
        let repository = FakeProductDetailRepository()
        repository.adjustResult = .failure(AppError.readOnly)
        let viewModel = make(repository: repository)
        viewModel.quantityText = "52"
        viewModel.reason = .expired
        await viewModel.save()
        #expect(viewModel.saved == nil)
        #expect(viewModel.generalError == .readOnly)
        #expect(viewModel.quantityText == "52")
        #expect(viewModel.canSave, "The person can try again")
    }

    @Test func nothingIsSentWhileSaveIsDisabled() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        viewModel.quantityText = "54"
        viewModel.reason = .damaged
        await viewModel.save()
        #expect(repository.adjusts.isEmpty)
        #expect(viewModel.saved == nil)
    }
}
