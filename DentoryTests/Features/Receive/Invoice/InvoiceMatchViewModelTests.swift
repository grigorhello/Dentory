import Foundation
import Testing
@testable import Dentory

/// Which product is this? (Appendix C `match`): the line as read, the clinic's products by name with their category and
/// stock, the search, and what the list says when it is empty.
@MainActor
struct InvoiceMatchViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(_ repository: FakeManualReceiveRepository) -> InvoiceMatchViewModel {
        InvoiceMatchViewModel(
            line: InvoiceLine.tempBond, repository: repository, formatters: formatters,
            clinicID: Session.demo.clinicID
        )
    }

    @Test func theClinicsProductsListByNameWithTheirCategoryAndStock() async {
        let repository = FakeManualReceiveRepository()
        let viewModel = make(repository)
        #expect(InvoiceMatchViewModel.title == "Which product is this?")
        #expect(viewModel.line.raw == "TEMPBOND NE 1PK")
        #expect(viewModel.emptyText.isEmpty, "Nothing is said while the products load")

        await viewModel.load()
        #expect(repository.productCalls == [Session.demo.clinicID])
        #expect(viewModel.pickableProducts.map(\.name) == [
            "Composite A2", "Endo file kit #15-40", "Gauze", "Root canal sealer", "Septocaine 4% 1:100,000"
        ])
        #expect(viewModel.caption(for: .septocaine) == "Anesthetic · 54 cartridges")
        #expect(viewModel.caption(for: .endoKit) == "Endodontics · 1 kit")
        #expect(viewModel.caption(for: .sealer) == "Endodontics · 0 unopened · 1 open")
        #expect(viewModel.caption(for: .gauze) == "8 packs", "No category, no separator")
    }

    @Test func theSearchFiltersByNameIgnoringCaseAndAccents() async {
        let viewModel = make(FakeManualReceiveRepository())
        await viewModel.load()
        viewModel.searchText = "  sÉpto "
        #expect(viewModel.pickableProducts == [.septocaine])
        viewModel.searchText = "tempbond"
        #expect(viewModel.pickableProducts.isEmpty)
        #expect(viewModel.emptyText == "No products match.")
    }

    @Test func aClinicWithoutProductsOrAFailedLoadSaysSo() async {
        let empty = FakeManualReceiveRepository()
        empty.productsResult = .success([])
        let none = make(empty)
        await none.load()
        #expect(none.emptyText == "No products yet.")

        let failing = FakeManualReceiveRepository()
        failing.productsResult = .failure(AppError.network)
        let failed = make(failing)
        await failed.load()
        #expect(failed.state == .failed(.network))
        #expect(failed.emptyText == "Couldn't load products. Close and reopen this sheet to try again.")
    }
}
