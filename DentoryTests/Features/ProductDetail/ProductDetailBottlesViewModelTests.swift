import Foundation
import Testing
@testable import Dentory

/// The bottles card of a multi-use product (MS-120): the noun per unit, the rows, Open a new bottle and Finished.
@MainActor
struct ProductDetailBottlesViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeProductDetailRepository, analytics: SpyAnalytics = SpyAnalytics()
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            repository: repository, cache: InMemoryResponseCache(), formatters: formatters,
            clinicID: Session.demo.clinicID, userID: Session.demo.userID, productID: ProductSummary.demo[0].id,
            analytics: analytics
        )
    }

    @Test func theBottleNounFollowsTheUnit() {
        #expect(ProductDetailViewModel.bottleNoun(forUnit: "bottles") == "bottle")
        #expect(ProductDetailViewModel.bottleNoun(forUnit: "syringes") == "syringe")
        #expect(ProductDetailViewModel.bottleNoun(forUnit: "Kits") == "kit")
        #expect(ProductDetailViewModel.bottleNoun(forUnit: "bags") == "bottle", "Anything else is a bottle")
    }

    @Test func aBottleOpenedYesterdayReadsYesterday() async {
        let yesterday = Session.demoNow.addingTimeInterval(-86_400)
        let detail = ProductDetail.fixture(
            tracking: .multiUse, quantity: 2, unopened: 1, openCount: 1,
            openBottles: [OpenBottle(id: UUID(), openedAt: yesterday, openedByName: "Sarah Mitchell")]
        )
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.bottleRows.first?.subtitle == "opened yesterday")
    }

    @Test func openingANewBottleCallsTheEngineReloadsAndToasts() async {
        let repository = FakeProductDetailRepository(detailResult: .success(.multiUseFixture(unit: "syringes")))
        let analytics = SpyAnalytics()
        let viewModel = make(repository: repository, analytics: analytics)
        await viewModel.load()
        #expect(viewModel.openNewBottleTitle == "Open a new syringe")
        #expect(viewModel.canOpenNewBottle)
        await viewModel.openNewBottle()
        #expect(repository.opens == [ProductSummary.demo[0].id])
        #expect(viewModel.bottleToast == .init(title: "Syringe opened", detail: nil))
        #expect(repository.detailCalls.count == 2, "The fresh detail brings the new row")
        viewModel.clearBottleToast()
        #expect(viewModel.bottleToast == nil)
        #expect(analytics.events == [.bottleOpened])
    }

    @Test func nothingUnopenedMeansNothingIsOpened() async {
        let detail = ProductDetail.multiUseFixture(unopened: 0)
        let repository = FakeProductDetailRepository(detailResult: .success(detail))
        let viewModel = make(repository: repository)
        await viewModel.load()
        #expect(!viewModel.canOpenNewBottle)
        await viewModel.openNewBottle()
        #expect(repository.opens.isEmpty)
    }

    @Test func aCountableProductOpensNothing() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.openNewBottle()
        #expect(repository.opens.isEmpty)
    }

    @Test func finishingRemovesTheRowAtOnceAndToastsTheLine() async {
        let detail = ProductDetail.multiUseFixture()
        let repository = FakeProductDetailRepository(detailResult: .success(detail))
        let analytics = SpyAnalytics()
        let viewModel = make(repository: repository, analytics: analytics)
        await viewModel.load()
        #expect(viewModel.bottlesLine == "1 unopened\u{00A0}· 2 open")
        let first = detail.openBottles[0].id
        repository.detailResult = .failure(AppError.network)
        await viewModel.finishBottle(first)
        #expect(repository.finishes == [first])
        #expect(analytics.events == [.bottleFinished])
        #expect(viewModel.bottleRows.map(\.id) == [detail.openBottles[1].id])
        #expect(viewModel.bottlesLine == "1 unopened\u{00A0}· 1 open")
        #expect(viewModel.detail?.quantity == 2, "A finished bottle leaves the stock")
        #expect(viewModel.bottleToast == .init(
            title: "Bottle finished", detail: "Septocaine 4% 1:100,000\u{00A0}· 1 unopened\u{00A0}· 1 open"
        ))
    }

    @Test func anUnknownBottleIsNotFinished() async {
        let repository = FakeProductDetailRepository(detailResult: .success(.multiUseFixture()))
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.finishBottle(UUID())
        #expect(repository.finishes.isEmpty)
    }

    @Test func aRefusedOpenBecomesAToastAndChangesNothing() async {
        let repository = FakeProductDetailRepository(detailResult: .success(.multiUseFixture()))
        repository.openResult = .failure(AppError.validation(field: nil, message: "Out of stock"))
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.openNewBottle()
        #expect(viewModel.generalError == .validation(field: nil, message: "Out of stock"))
        #expect(viewModel.bottleToast == nil)
        #expect(viewModel.bottlesLine == "1 unopened\u{00A0}· 2 open")
    }
}

extension ProductDetail {
    /// A multi-use version of the demo product: 1 unopened and 2 open (Sarah's, then Michael's).
    nonisolated static func multiUseFixture(unit: String = "bottles", unopened: Decimal = 1) -> ProductDetail {
        let base = fixture(
            tracking: .multiUse, quantity: unopened + 2, unopened: unopened, openCount: 2,
            openBottles: [
                OpenBottle(
                    id: UUID(), openedAt: Session.demoNow.addingTimeInterval(-3 * 86_400),
                    openedByName: "Sarah Mitchell"
                ),
                OpenBottle(id: UUID(), openedAt: Session.demoNow, openedByName: "Michael Reyes")
            ]
        )
        return ProductDetail(
            id: base.id, name: base.name, categoryName: base.categoryName, unit: unit, packUnit: nil, packSize: nil,
            minimum: base.minimum, target: base.target, tracking: .multiUse, location: base.location,
            status: base.status, quantity: base.quantity, unopened: base.unopened, openCount: base.openCount,
            missingExpiryQuantity: 0, usedInLast30Days: base.usedInLast30Days, lastCountedAt: base.lastCountedAt,
            toBuyItemID: nil, batches: [], openBottles: base.openBottles, history: []
        )
    }
}
