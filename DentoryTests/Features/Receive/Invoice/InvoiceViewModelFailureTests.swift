import Foundation
import Testing
@testable import Dentory

/// A reading that failed (the MS-129 fix): opened from Receive delivery's Continue reviewing, it shows the failure at
/// once; Receive manually sets it aside and Back shows it so; Try again sets it aside once, before the screen goes back
/// to the options, so their list does not show it; and nothing else is set aside by Try again.
@MainActor
struct InvoiceViewModelFailureTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let invoiceID = UUID()

    private func opened(_ repository: FakeInvoiceRepository) -> InvoiceViewModel {
        InvoiceViewModel(
            invoiceID: invoiceID, repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            pause: { _ in }
        )
    }

    /// An invoice whose reading failed while the admin was away, opened as Continue reviewing opens it.
    private func openedFailed(_ repository: FakeInvoiceRepository) async -> InvoiceViewModel {
        repository.readings = [.success(.ended(invoiceID, .failed))]
        let viewModel = opened(repository)
        await viewModel.load()
        return viewModel
    }

    /// Waits, briefly, for work the screen leaves running.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func aReadingThatFailedWhileTheAdminWasAwayOpensOnTheFailure() async {
        let repository = FakeInvoiceRepository()
        let viewModel = await openedFailed(repository)
        #expect(viewModel.state == .failed, "Couldn't read opens Try again and Receive manually")
        #expect(viewModel.header == nil)
        #expect(repository.calls == [.invoice(invoiceID)], "Nothing is read again, and nothing more is asked")
    }

    @Test func receiveManuallySetsTheInvoiceAsideAndBackShowsItSo() async {
        let repository = FakeInvoiceRepository()
        let viewModel = await openedFailed(repository)
        viewModel.setAside()
        #expect(viewModel.state == .closed)
        await eventually { repository.calls.contains(.discard(invoiceID)) }

        await viewModel.load()
        #expect(viewModel.state == .closed, "Back from Receive manually lands on the invoice set aside")
        #expect(
            repository.calls == [.invoice(invoiceID), .discard(invoiceID)],
            "Set aside once, so Continue reviewing lists it no more"
        )
    }

    @Test func tryAgainSetsTheInvoiceAsideOnceBeforeTheScreenGoesBack() async {
        let repository = FakeInvoiceRepository()
        let viewModel = await openedFailed(repository)

        async let first: Void = viewModel.setAsideToCaptureAgain()
        async let second: Void = viewModel.setAsideToCaptureAgain()
        _ = await (first, second)
        #expect(
            repository.calls == [.invoice(invoiceID), .discard(invoiceID)],
            "Set aside once, and before the options come back, so their list does not show it"
        )
        #expect(viewModel.state == .failed, "The failure stays on screen until the screen goes back")
    }

    @Test func tryAgainSetsNothingAsideUnlessTheReadingFailed() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID))]
        let viewModel = opened(repository)
        await viewModel.load()
        await viewModel.setAsideToCaptureAgain()
        #expect(repository.calls == [.invoice(invoiceID)])
        #expect(viewModel.state == .ready)
    }
}
