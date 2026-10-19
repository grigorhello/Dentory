import Foundation
import Testing
@testable import Dentory

/// Product detail's Edit and Delete product sheets (MS-117).
@MainActor
struct ProductDetailEditDeleteTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeProductDetailRepository = FakeProductDetailRepository(),
        cache: ResponseCaching = InMemoryResponseCache()
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            userID: Session.demo.userID, productID: ProductSummary.demo[0].id
        )
    }

    @Test func deleteProductAsksThenArchivesAndLeaves() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        await viewModel.load()
        viewModel.askToDelete()
        #expect(viewModel.sheet == .delete)
        #expect(viewModel.deleteTitle == "Delete Septocaine 4% 1:100,000?")
        #expect(viewModel.deleteMessage == "54 cartridges still in stock. The product and its history are archived, "
            + "not erased. It disappears from Inventory, To buy and procedures.")
        viewModel.keepProduct()
        #expect(viewModel.sheet == nil)
        viewModel.askToDelete()
        await viewModel.deleteProduct()
        #expect(repository.archived == [ProductSummary.demo[0].id])
        #expect(viewModel.sheet == nil)
        #expect(viewModel.isDeleted)
    }

    @Test func deleteOfAnEmptyProductSkipsTheStockSentence() async {
        let detail = ProductDetail.fixture(status: .outOfStock, quantity: 0, unopened: 0, batches: [])
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        #expect(viewModel.deleteMessage.hasPrefix("The product and its history are archived"))
    }

    @Test func aRefusedDeleteStaysOnTheScreen() async {
        let repository = FakeProductDetailRepository()
        repository.archiveResult = .failure(AppError.forbidden)
        let viewModel = make(repository: repository)
        await viewModel.load()
        viewModel.askToDelete()
        await viewModel.deleteProduct()
        #expect(viewModel.generalError == .forbidden)
        #expect(!viewModel.isDeleted)
    }

    @Test func addToBuyKeepsWhatTheEditSheetStartsFrom() async {
        let detail = ProductDetail.fixture()
        let viewModel = make(repository: FakeProductDetailRepository(detailResult: .success(detail)))
        await viewModel.load()
        await viewModel.addToBuy()
        #expect(viewModel.isOnToBuy)
        #expect(viewModel.detail?.categoryID == detail.categoryID, "Add to buy dropped the category")
        #expect(viewModel.detail?.supplier == detail.supplier, "Add to buy dropped the supplier")
    }

    @Test func editOpensTheSheetAndSavingReloads() async {
        let repository = FakeProductDetailRepository()
        let viewModel = make(repository: repository)
        viewModel.edit()
        #expect(viewModel.sheet == nil, "Nothing to edit before the detail loaded")
        await viewModel.load()
        viewModel.edit()
        #expect(viewModel.sheet == .edit)
        await viewModel.productSaved()
        #expect(viewModel.sheet == nil)
        #expect(repository.detailCalls.count == 2, "The saved fields are read back")
    }
}
