import Foundation
import Testing
@testable import Dentory

/// Review invoice up to its review (MS-129): captured pages are uploaded as their invoice, created and read, once
/// (again only after Try again); an invoice opened from Receive delivery is followed; failures say what to do next;
/// Receive manually instead sets the invoice aside for good; and leaving the screen stops the questions, never the
/// upload.
@MainActor
struct InvoiceViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let document = InvoiceDocument(
        source: .camera,
        pages: [InvoiceDocument.Page(kind: .jpeg, data: Data(count: 8)), .init(kind: .jpeg, data: Data(count: 9))]
    )
    private let invoiceID = UUID()

    private func captured(_ repository: FakeInvoiceRepository) -> InvoiceViewModel {
        InvoiceViewModel(
            document: document, repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            pause: { _ in }
        )
    }

    private func opened(_ repository: FakeInvoiceRepository) -> InvoiceViewModel {
        InvoiceViewModel(
            invoiceID: invoiceID, repository: repository, formatters: formatters, clinicID: Session.demo.clinicID,
            pause: { _ in }
        )
    }

    /// Waits, briefly, for work the screen leaves running.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Captured pages

    @Test func capturedPagesAreUploadedAsTheirInvoiceThenReadUntilReady() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.reading(document.id)), .success(.ready(document.id))]
        let viewModel = captured(repository)
        #expect(viewModel.state == .uploading)
        #expect(viewModel.invoiceID == document.id)

        await viewModel.load()
        #expect(repository.calls == [
            .upload(document.id, pages: 2), .create(document.id), .startReading(document.id),
            .invoice(document.id), .invoice(document.id)
        ])
        #expect(viewModel.state == .ready)
        #expect(viewModel.header == "Patterson Dental · INV-10092 · $449.00")
        #expect(viewModel.banner == "AI read 4 lines. Check each one, then confirm.")
    }

    @Test func theUploadShowsAsTheReadingState() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        let seen = StateBox()
        repository.duringUpload = { await seen.keep(MainActor.run { viewModel.state }) }
        await viewModel.load()
        #expect(seen.value == .uploading)
        #expect(viewModel.header != nil)
    }

    @Test func aFailedUploadOffersTryAgainWhichSendsTheSamePagesToTheSameInvoice() async {
        let repository = FakeInvoiceRepository()
        repository.uploadError = AppError.network
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        await viewModel.load()
        #expect(viewModel.state == .uploadFailed(.network))
        #expect(repository.calls == [.upload(document.id, pages: 2)])

        repository.uploadError = nil
        viewModel.retry()
        #expect(viewModel.state == .uploading)
        #expect(viewModel.attempt == 1)
        await viewModel.load()
        #expect(viewModel.state == .ready)
        #expect(repository.calls.filter { $0 == .upload(document.id, pages: 2) }.count == 2)
        #expect(repository.calls.filter { $0 == .create(document.id) }.count == 1)
    }

    @Test func comingBackAfterAFailedUploadSendsNothingUntilTryAgain() async {
        let repository = FakeInvoiceRepository()
        repository.uploadError = AppError.network
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        await viewModel.load()
        repository.uploadError = nil

        await viewModel.load()
        #expect(repository.calls == [.upload(document.id, pages: 2)], "Only Try again sends the pages again")
        #expect(viewModel.state == .uploadFailed(.network))

        viewModel.retry()
        await viewModel.load()
        #expect(repository.calls == [
            .upload(document.id, pages: 2), .upload(document.id, pages: 2), .create(document.id),
            .startReading(document.id), .invoice(document.id)
        ])
        #expect(viewModel.state == .ready)
    }

    @Test func anInvoiceRefusedOnCreationIsAFailedUploadToo() async {
        let repository = FakeInvoiceRepository()
        repository.createError = AppError.readOnly
        let viewModel = captured(repository)
        await viewModel.load()
        #expect(viewModel.state == .uploadFailed(.readOnly))
        #expect(!repository.calls.contains(.startReading(document.id)))
    }

    @Test func aRequestToReadThatIsLostIsMadeAgainWhileFollowingAtMostThreeTimes() async {
        let repository = FakeInvoiceRepository()
        repository.startError = AppError.network
        let waiting = InvoiceSummary.reading(document.id, started: false)
        repository.readings = Array(repeating: .success(waiting), count: 5) + [.success(.ended(document.id, .failed))]
        let viewModel = captured(repository)
        await viewModel.load()
        #expect(repository.calls.filter { $0 == .startReading(document.id) }.count == 3)
        #expect(viewModel.state == .failed)
    }

    // MARK: - An invoice opened from Receive delivery

    @Test func anInvoiceBeingReadIsFollowedUntilItIsRead() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [
            .success(.reading(invoiceID)), .success(.reading(invoiceID)), .success(.ready(invoiceID))
        ]
        let viewModel = opened(repository)
        #expect(viewModel.state == .loading)
        await viewModel.load()
        #expect(viewModel.state == .ready)
        #expect(repository.calls == [.invoice(invoiceID), .invoice(invoiceID), .invoice(invoiceID)])
    }

    @Test func aReadingThatFailsShowsTheFailureWithoutAHeader() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.reading(invoiceID)), .success(.ended(invoiceID, .failed))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.state == .failed)
        #expect(viewModel.header == nil)
        #expect(viewModel.banner == nil)
    }

    @Test func anInvoiceReceivedOrSetAsideSinceIsClosed() async {
        for status in [InvoiceSummary.Status.confirmed, .discarded] {
            let repository = FakeInvoiceRepository()
            repository.readings = [.success(.ended(invoiceID, status))]
            let viewModel = opened(repository)
            await viewModel.load()
            #expect(viewModel.state == .closed)
        }
    }

    @Test func aFirstLoadThatFailsSaysSoAndTryAgainLoadsAgain() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.failure(AppError.network), .success(.ready(invoiceID))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.state == .loadFailed(.network))

        viewModel.retry()
        #expect(viewModel.state == .loading)
        await viewModel.load()
        #expect(viewModel.state == .ready)
    }

    @Test func aQuestionThatFailsWhileTheInvoiceIsReadWaitsForTheNextOne() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.reading(invoiceID)), .failure(AppError.network), .success(.ready(invoiceID))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.state == .ready)
    }

    @Test func tryAgainDoesNothingWhileNothingFailed() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID))]
        let viewModel = opened(repository)
        await viewModel.load()
        viewModel.retry()
        #expect(viewModel.attempt == 0)
        #expect(viewModel.state == .ready)
    }

    // MARK: - Leaving, and Receive manually instead

    @Test func leavingTheScreenStopsTheQuestionsButTheUploadCarriesOn() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.reading(document.id))]
        repository.duringUpload = { try? await Task.sleep(for: .milliseconds(50)) }
        let viewModel = captured(repository)
        let screen = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(10))
        screen.cancel()
        await screen.value
        await eventually { repository.calls.contains(.startReading(document.id)) }
        #expect(repository.calls == [.upload(document.id, pages: 2), .create(document.id), .startReading(document.id)])
        #expect(viewModel.state == .reading, "The invoice is read on the server; the bell says when it is ready")
    }

    @Test func receiveManuallyInsteadDuringTheUploadStopsItAndSetsTheInvoiceAside() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        repository.duringUpload = { await MainActor.run { viewModel.setAside() } }
        await viewModel.load()
        await eventually { repository.calls.contains(.discard(document.id)) }
        #expect(!repository.calls.contains(.create(document.id)), "No invoice is created after the tap")
        #expect(repository.calls.contains(.discard(document.id)))
        #expect(viewModel.state == .closed, "No failure is shown for an upload stopped on purpose")
    }

    @Test func comingBackAfterReceiveManuallyInsteadDuringTheUploadSendsNothingAgain() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        repository.duringUpload = { await MainActor.run { viewModel.setAside() } }
        await viewModel.load()
        await eventually { repository.calls.contains(.discard(document.id)) }
        repository.duringUpload = nil

        await viewModel.load()
        #expect(repository.calls == [.upload(document.id, pages: 2), .discard(document.id)])
        #expect(viewModel.state == .closed, "Back lands on the invoice set aside, never on its reading")
        #expect(viewModel.header == nil)
    }

    @Test func receiveManuallyAfterAFailedUploadSetsThePagesAsideForGood() async {
        let repository = FakeInvoiceRepository()
        repository.uploadError = AppError.network
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        await viewModel.load()
        viewModel.setAside()
        #expect(viewModel.state == .closed)
        await eventually { repository.calls.contains(.discard(document.id)) }

        repository.uploadError = nil
        viewModel.retry()
        await viewModel.load()
        #expect(repository.calls == [.upload(document.id, pages: 2), .discard(document.id)])
        #expect(viewModel.state == .closed)
        #expect(viewModel.attempt == 0, "Nothing is tried again once set aside")
    }

    @Test func receiveManuallyInsteadWhileTheInvoiceIsCreatedSetsItAsideOnceItExists() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(document.id))]
        let viewModel = captured(repository)
        repository.duringCreate = { await MainActor.run { viewModel.setAside() } }
        await viewModel.load()
        await eventually { repository.calls.contains(.discard(document.id)) }
        #expect(
            repository.calls == [.upload(document.id, pages: 2), .create(document.id), .discard(document.id)],
            "The invoice is discarded after its creation answers, and never read"
        )
        #expect(viewModel.state == .closed)
    }

    @Test func receiveManuallyInsteadWhileReadingSetsTheInvoiceAside() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ended(invoiceID, .failed))]
        let viewModel = opened(repository)
        await viewModel.load()
        viewModel.setAside()
        await eventually { repository.calls.contains(.discard(invoiceID)) }
        #expect(repository.calls.last == .discard(invoiceID))
    }

    // MARK: - What it says

    @Test func theHeaderIsInTheInvoicesCurrencyAndLeavesOutWhatTheInvoiceDoesNotShow() async {
        let cases: [(InvoiceSummary, String?)] = [
            (.ready(invoiceID, currency: "CAD"), "Patterson Dental · INV-10092 · CA$449.00"),
            (.ready(invoiceID, supplier: nil), "INV-10092 · $449.00"),
            (.ready(invoiceID, number: "", total: nil), "Patterson Dental"),
            (.ready(invoiceID, supplier: nil, number: nil, total: nil), nil)
        ]
        for (invoice, header) in cases {
            let repository = FakeInvoiceRepository()
            repository.readings = [.success(invoice)]
            let viewModel = opened(repository)
            await viewModel.load()
            #expect(viewModel.header == header)
        }
    }

    @Test func oneLineReadsInTheSingular() async {
        let repository = FakeInvoiceRepository()
        repository.readings = [.success(.ready(invoiceID, lines: 1))]
        let viewModel = opened(repository)
        await viewModel.load()
        #expect(viewModel.banner == "AI read 1 line. Check each one, then confirm.")
    }

    @Test func theCopyFollowsThePRDAndTheTicket() {
        #expect(InvoiceViewModel.title == "Review invoice")
        #expect(InvoiceViewModel.readingTitle == "Reading invoice")
        #expect(InvoiceViewModel.readingCaption == "Usually under 20 seconds.")
        #expect(InvoiceViewModel.receiveManuallyInstead == "Receive manually instead")
        #expect(
            InvoiceViewModel.readingFailure == "We couldn't read this invoice. Try a clearer photo or receive manually."
        )
        #expect(InvoiceViewModel.pollInterval == .seconds(2))
    }
}

/// A state seen from inside the fake repository.
private final class StateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: InvoiceViewModel.State?

    var value: InvoiceViewModel.State? { lock.withLock { kept } }

    func keep(_ state: InvoiceViewModel.State) {
        lock.withLock { kept = state }
    }
}
