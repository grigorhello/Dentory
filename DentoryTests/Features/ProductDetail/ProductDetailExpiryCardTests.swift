import Foundation
import Testing
@testable import Dentory

/// The expiry card (MS-116, MS-119): the batch rows soonest first across years, the days left and their tones, the
/// emphasis on the soonest batch within 90 days, and the total line with the undated stock.
@MainActor
struct ProductDetailExpiryCardTests {
    /// October 2, 2026 in New York, the frames' day: the demo batches expire in December.
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeProductDetailRepository = FakeProductDetailRepository()
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            repository: repository, cache: InMemoryResponseCache(), formatters: formatters,
            clinicID: Session.demo.clinicID, userID: Session.demo.userID, productID: ProductSummary.demo[0].id,
            analytics: SpyAnalytics()
        )
    }

    @Test func batchRowsAreSoonestFirstWithTheDaysLeftAndTheTotals() async {
        let viewModel = make()
        await viewModel.load()
        let rows = viewModel.batchRows
        #expect(rows.map(\.lot) == ["A112", "B441"])
        #expect(rows.first?.dateText == "Dec 2026", "Batches have month precision, so no day is shown")
        #expect(rows.first?.daysText == "in 90 days", "Days run to the last day of the expiry month (PRD)")
        #expect(rows.first?.daysTone == .warning)
        #expect(rows.map(\.quantityText) == ["20", "34"])
        #expect(viewModel.expiryTotalLine == "54 of 54 tracked · 54 expire within 90 days")
        #expect(viewModel.unit == "cartridges")
    }

    @Test func undatedStockCountsInTheTotalButHasNoRow() async {
        let undated = ProductBatch(id: UUID(), expiryMonth: nil, lot: nil, quantity: 4)
        let detail = ProductDetail.fixture(quantity: 58, batches: ProductDetail.demoSeptocaine().batches + [undated])
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.batchRows.count == 2)
        #expect(viewModel.expiryTotalLine == "54 of 58 tracked · 54 expire within 90 days")
    }

    @Test func batchesSortAcrossYearsAndAPastMonthReadsExpired() async {
        let detail = ProductDetail.fixture(batches: [
            ProductBatch(id: UUID(), expiryMonth: CalendarDay(year: 2027, month: 3, day: 1), lot: "C3", quantity: 5),
            ProductBatch(id: UUID(), expiryMonth: CalendarDay(year: 2026, month: 9, day: 1), lot: "S9", quantity: 2),
            ProductBatch(id: UUID(), expiryMonth: CalendarDay(year: 2026, month: 12, day: 1), lot: "D12", quantity: 7)
        ])
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        let rows = viewModel.batchRows
        #expect(rows.map(\.lot) == ["S9", "D12", "C3"], "Soonest first across years")
        #expect(rows.map(\.dateText) == ["Sep 2026", "Dec 2026", "Mar 2027"])
        #expect(rows[0].daysText == "Expired" && rows[0].daysTone == .danger)
        #expect(rows[2].daysTone == .success, "Green beyond 90 days")
        #expect(rows.map(\.isEmphasized) == [true, false, false], "The soonest batch within 90 days stands out")
    }

    @Test func noBatchIsEmphasisedWhenTheSoonestIsFarOff() async {
        let detail = ProductDetail.fixture(batches: [
            ProductBatch(id: UUID(), expiryMonth: CalendarDay(year: 2028, month: 6, day: 1), lot: nil, quantity: 5)
        ])
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.batchRows.map(\.isEmphasized) == [false])
    }

    @Test func daysLeftTonesFollowThePRD() {
        #expect(ProductDetailViewModel.tone(forDaysLeft: -1) == .danger)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 30) == .danger)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 31) == .warning)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 90) == .warning)
        #expect(ProductDetailViewModel.tone(forDaysLeft: 91) == .success, "Green beyond 90 days (MS-119)")
    }
}
