import Foundation
import Testing
@testable import Dentory

@MainActor
struct BatchViewModelTests {
    private func make(
        detail: ProductDetail = .withUndated(4),
        mode: BatchViewModel.Mode = .add,
        repository: FakeProductDetailRepository = FakeProductDetailRepository(),
        locale: Locale = Locale(identifier: "en_US")
    ) -> BatchViewModel {
        let formatters = ClinicFormatters(
            currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
            locale: locale, clock: FixedClock(Session.demoNow)
        )
        return BatchViewModel(detail: detail, mode: mode, repository: repository, formatters: formatters)
    }

    private let december = CalendarDay(year: 2026, month: 12, day: 1)

    @Test func addExpiryStartsFromTheUndatedStock() {
        let viewModel = make()
        #expect(viewModel.title == "Add expiry")
        #expect(viewModel.productName == "Septocaine 4% 1:100,000")
        #expect(viewModel.unit == "cartridges")
        #expect(viewModel.undated == 4)
        #expect(viewModel.quantityText == "4", "How many starts on the undated quantity")
        #expect(viewModel.expiryMonth == nil && viewModel.lot.isEmpty)
        #expect(!viewModel.canSave, "No month yet")
        #expect(viewModel.openingMonth == CalendarDay(year: 2026, month: 10, day: 1), "The wheels open on this month")
        #expect(viewModel.years == 2023...2036)
    }

    @Test func saveWaitsForAMonthAndAPositiveQuantity() {
        let viewModel = make()
        viewModel.expiryMonth = december
        #expect(viewModel.canSave)
        viewModel.quantityText = "0"
        #expect(!viewModel.canSave, "An empty batch is not added")
        viewModel.quantityText = "abc"
        #expect(viewModel.quantityError == "Enter a number")
        #expect(!viewModel.canSave)
    }

    @Test func theHintSaysWhereTheQuantityComesFrom() {
        let viewModel = make()
        #expect(viewModel.quantityHint == "4 cartridges come from stock with no expiry date.")
        viewModel.quantityText = "6"
        #expect(viewModel.quantityHint == "4 come from stock with no expiry date, 2 are added as a Data correction.")
        let dated = make(detail: .demoSeptocaine())
        #expect(dated.undated == 0 && dated.quantityText.isEmpty)
        dated.quantityText = "10"
        #expect(dated.quantityHint == "10 cartridges are added to stock as a Data correction.")
    }

    @Test func savingAddsTheBatchAndReadsTheToast() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        viewModel.expiryMonth = december
        viewModel.lot = " C17 "
        await viewModel.save()
        #expect(repository.upserts == [.init(
            productID: ProductSummary.demo[0].id, batchID: nil, expiryMonth: december, quantity: 4, lot: "C17"
        )])
        #expect(viewModel.saved == .init(
            title: "Expiry saved", detail: "Septocaine 4% 1:100,000 · 4 cartridges · Dec 2026"
        ))
    }

    @Test func editBatchStartsFromTheBatchAndWaitsForAChange() async {
        let batch = ProductDetail.demoSeptocaine().batches[0]
        let repository = FakeProductDetailRepository()
        let viewModel = make(detail: .demoSeptocaine(), mode: .edit(batch), repository: repository)
        #expect(viewModel.title == "Edit batch")
        #expect(viewModel.expiryMonth == batch.expiryMonth)
        #expect(viewModel.quantityText == "20" && viewModel.lot == "A112")
        #expect(!viewModel.canSave, "Nothing changed")
        viewModel.lot = "A113"
        #expect(viewModel.canSave)
        #expect(viewModel.quantityHint == nil)
        viewModel.quantityText = "18"
        #expect(viewModel.quantityHint == "2 fewer than before, recorded as a Data correction.")
        viewModel.quantityText = "0"
        #expect(viewModel.canSave, "Edit batch may empty a batch")
        viewModel.quantityText = "21"
        #expect(viewModel.quantityHint == "1 more than before, recorded as a Data correction.")
        await viewModel.save()
        #expect(repository.upserts.first?.batchID == batch.id)
        #expect(repository.upserts.first?.quantity == 21 && repository.upserts.first?.lot == "A113")
    }

    @Test func theYearsStretchToAnOldBatch() {
        let old = ProductBatch(
            id: UUID(), expiryMonth: CalendarDay(year: 2019, month: 3, day: 1), lot: nil, quantity: 2
        )
        let viewModel = make(detail: .demoSeptocaine(), mode: .edit(old))
        #expect(viewModel.years == 2019...2036)
    }

    @Test func aRefusalKeepsWhatWasTyped() async {
        let repository = FakeProductDetailRepository()
        repository.upsertResult = .failure(AppError.forbidden)
        let viewModel = make(repository: repository)
        viewModel.expiryMonth = december
        await viewModel.save()
        #expect(viewModel.generalError == .forbidden)
        #expect(viewModel.saved == nil)
        #expect(viewModel.expiryMonth == december && viewModel.quantityText == "4")
    }

    @Test func anOfflineSaveIsQueuedAndStillCloses() async {
        let repository = FakeProductDetailRepository()
        repository.upsertResult = .success(.queued)
        let viewModel = make(repository: repository)
        viewModel.expiryMonth = december
        await viewModel.save()
        #expect(viewModel.saved?.title == "Expiry saved")
    }

    @Test func theQuantityReadsTheClinicsLocale() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(
            detail: .withUndated(Decimal(string: "2.5") ?? 0), repository: repository,
            locale: Locale(identifier: "fr_CA")
        )
        #expect(viewModel.quantityText == "2,5")
        viewModel.expiryMonth = december
        await viewModel.save()
        #expect(repository.upserts.first?.quantity == Decimal(string: "2.5"))
    }
}

extension ProductDetail {
    /// Septocaine with `undated` more cartridges that have no expiry date.
    nonisolated static func withUndated(_ undated: Decimal) -> ProductDetail {
        let base = ProductDetail.demoSeptocaine()
        return ProductDetail.fixture(
            status: .missingExpiry, quantity: base.quantity + undated, unopened: base.unopened + undated,
            batches: base.batches + [ProductBatch(id: UUID(), expiryMonth: nil, lot: nil, quantity: undated)]
        )
    }
}
