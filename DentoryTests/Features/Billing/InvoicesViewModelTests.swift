import Foundation
import Testing
@testable import Dentory

/// Invoices (f35, MS-141): the rows' date, amount and status, the empty state, and the cache.
@MainActor
struct InvoicesViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "CAD", timeZone: TimeZone(identifier: "America/Toronto") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        _ repository: FakeBillingRepository = FakeBillingRepository(), cache: ResponseCaching = InMemoryResponseCache(),
        trialEndsAt: Date? = BillingSummary.demoTrialEnd
    ) -> InvoicesViewModel {
        InvoicesViewModel(
            clinicID: Session.demo.clinicID, repository: repository, cache: cache, formatters: formatters,
            trialEndsAt: trialEndsAt
        )
    }

    @Test func eachInvoiceReadsItsDateAmountAndStatus() async {
        let repository = FakeBillingRepository()
        repository.invoices = BillingInvoice.demo
        let viewModel = make(repository)
        await viewModel.load()
        #expect(viewModel.rows.map(\.date) == ["Mar 9, 2027", "Feb 6, 2027", "Jan 6, 2027"])
        #expect(viewModel.rows.map(\.number) == ["DEN-0003", "DEN-0002", "DEN-0001"])
        #expect(viewModel.rows.allSatisfy { $0.amount == "$49.50" }, "US dollars, whatever the clinic's currency")
        #expect(viewModel.rows.map(\.status) == ["Open", "Paid", "Paid"])
        #expect(viewModel.rows.map(\.tone) == [.warning, .success, .success])
    }

    @Test func theStatusesReadAsTheTicketSays() {
        #expect(InvoicesViewModel.status(.paid) == ("Paid", .success))
        #expect(InvoicesViewModel.status(.open) == ("Open", .warning))
        #expect(InvoicesViewModel.status(.draft) == ("Open", .warning))
        #expect(InvoicesViewModel.status(.uncollectible) == ("Failed", .danger))
        #expect(InvoicesViewModel.status(.void) == ("Void", .neutral))
        #expect(InvoicesViewModel.amount(cents: 9900, currency: "usd") == "$99.00")
    }

    @Test func noInvoicesSaysWhenTheFirstComes() async {
        let viewModel = make()
        await viewModel.load()
        #expect(viewModel.rows.isEmpty)
        #expect(InvoicesViewModel.emptyTitle == "No invoices yet")
        #expect(viewModel.emptyCaption == "Your first invoice is issued when the trial ends on January 6, 2027. "
            + "Each one appears here, and its receipt goes to your billing emails.")
        let ended = make(trialEndsAt: Session.demoNow.addingTimeInterval(-86_400))
        #expect(ended.emptyCaption
            == "Each invoice appears here once it is issued, and its receipt goes to your billing emails.")
    }

    @Test func theLastListShowsOffline() async {
        let cache = InMemoryResponseCache()
        let repository = FakeBillingRepository()
        repository.invoices = BillingInvoice.demo
        await make(repository, cache: cache).load()
        let offline = FakeBillingRepository()
        offline.failure = AppError.network
        let viewModel = make(offline, cache: cache)
        #expect(viewModel.rows.count == 3, "The cached list shows at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        let nothingCached = make(offline)
        await nothingCached.load()
        #expect(nothingCached.state == .failed(.network))
    }
}
