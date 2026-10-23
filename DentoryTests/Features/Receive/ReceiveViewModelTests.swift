import Foundation
import Testing
@testable import Dentory

/// Receive delivery (f22): the invoices to continue and the lines waiting for delivery with their captions, the cache,
/// the pickers behind Take a photo and Upload, and what happens to captured pages.
struct ReceiveViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        _ repository: FakeReceiveRepository = FakeReceiveRepository(), canScan: Bool = true,
        cache: ResponseCaching = InMemoryResponseCache(), loads: Bool = true
    ) async -> ReceiveViewModel {
        let viewModel = ReceiveViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            canScan: canScan
        )
        if loads {
            await viewModel.load()
        }
        return viewModel
    }

    private func item(supplier: String?, orderedAt: Date = Session.demoNow) -> WaitingItem {
        WaitingItem(
            id: UUID(), productID: UUID(), name: "Gauze", unit: "packs", supplier: supplier, quantity: 1,
            orderedAt: orderedAt
        )
    }

    private func document(_ source: InvoiceDocument.Source, bytes: [Int]) -> InvoiceDocument {
        InvoiceDocument(source: source, pages: bytes.map { InvoiceDocument.Page(kind: .jpeg, data: Data(count: $0)) })
    }

    // MARK: - Lists

    @Test func theDemoClinicHasAnInvoiceToContinueAndFiveLinesWaiting() async {
        let repository = FakeReceiveRepository()
        let viewModel = await make(repository)
        #expect(viewModel.state == .loaded)
        #expect(repository.calls == [Session.demo.clinicID])
        #expect(viewModel.invoices.count == 1)
        #expect(viewModel.invoiceLine(for: viewModel.invoices[0]) == "Patterson · 8:55\u{202F}AM")
        #expect(viewModel.waiting.map(\.name) == [
            "Gauze", "Needle 27g short", "Prophy angle", "Root canal sealer", "Temporary cement"
        ])
        let needles = viewModel.waiting[1]
        #expect(viewModel.waitingLine(for: needles) == "Patterson · ordered Oct 1")
        #expect(viewModel.quantityText(for: needles) == "60")
        #expect(viewModel.spokenQuantity(for: needles) == "60 needles ordered")
        #expect(viewModel.spokenQuantity(for: viewModel.waiting[3]) == "1 kit ordered")
    }

    @Test func aLineWithoutASupplierStartsWithOrdered() async {
        let viewModel = await make()
        #expect(viewModel.waitingLine(for: item(supplier: nil)) == "Ordered Oct 2")
        #expect(viewModel.waitingLine(for: item(supplier: "")) == "Ordered Oct 2")
    }

    @Test func anInvoiceIsNamedByItsSupplierOnceReadAndDatedLikeAlerts() async {
        let viewModel = await make()
        let day: TimeInterval = 24 * 60 * 60
        let reading = PendingInvoice(id: UUID(), status: .reading, supplier: nil, createdAt: Session.demoNow)
        let yesterday = PendingInvoice(
            id: UUID(), status: .ready, supplier: "Henry Schein", createdAt: Session.demoNow.addingTimeInterval(-day)
        )
        let older = PendingInvoice(
            id: UUID(), status: .ready, supplier: "Benco", createdAt: Session.demoNow.addingTimeInterval(-4 * day)
        )
        #expect(viewModel.invoiceLine(for: reading) == "Invoice · 5:27\u{202F}AM")
        #expect(viewModel.invoiceLine(for: yesterday) == "Henry Schein · Yesterday")
        #expect(viewModel.invoiceLine(for: older) == "Benco · Sep 28")
    }

    @Test func nothingWaitingLeavesBothListsEmpty() async {
        let repository = FakeReceiveRepository()
        repository.result = .success(ReceiveOverview(invoices: [], waiting: []))
        let viewModel = await make(repository)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.invoices.isEmpty)
        #expect(viewModel.waiting.isEmpty)
    }

    @Test func aRefusedFirstLoadShowsWhy() async {
        let repository = FakeReceiveRepository()
        repository.result = .failure(AppError.forbidden)
        let viewModel = await make(repository)
        #expect(viewModel.state == .failed(.forbidden))
        #expect(viewModel.overview == nil)
    }

    @Test func aFailedReloadKeepsTheLastListsAndTheCacheServesThemNextTime() async {
        let repository = FakeReceiveRepository()
        let cache = InMemoryResponseCache()
        let viewModel = await make(repository, cache: cache)
        repository.result = .failure(AppError.network)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.waiting.count == 5)

        let offline = await make(repository, cache: cache, loads: false)
        #expect(offline.waiting.count == 5, "Shown from the cache before any load")
        await offline.load()
        #expect(offline.state == .loaded)
    }

    // MARK: - Pickers

    @Test func takeAPhotoOpensTheScannerWhereTheDeviceHasOne() async {
        let viewModel = await make(canScan: true)
        viewModel.takePhoto()
        #expect(viewModel.isScannerPresented)
        #expect(!viewModel.isPhotoPickerPresented)
    }

    @Test func takeAPhotoOpensPhotosWithoutAScanner() async {
        let viewModel = await make(canScan: false)
        viewModel.takePhoto()
        #expect(viewModel.isPhotoPickerPresented)
        #expect(!viewModel.isScannerPresented)
    }

    @Test func uploadOpensFiles() async {
        let viewModel = await make()
        viewModel.uploadFile()
        #expect(viewModel.isFileImporterPresented)
    }

    // MARK: - Captured pages

    @Test func scannedPagesGoToReviewInvoiceAndCloseTheScanner() async {
        let viewModel = await make()
        viewModel.takePhoto()
        await viewModel.capture { () async throws(InvoiceCaptureError) in
            self.document(.camera, bytes: [1_200_000, 900_000])
        }
        #expect(!viewModel.isScannerPresented)
        #expect(viewModel.pendingRoute == .newInvoice(source: .camera, pageCount: 2))
        #expect(viewModel.message == nil)
        viewModel.clearPendingRoute()
        #expect(viewModel.pendingRoute == nil)
    }

    @Test func aFileGoesToReviewInvoiceAsOnePage() async {
        let viewModel = await make()
        await viewModel.capture { () async throws(InvoiceCaptureError) in
            InvoiceDocument(source: .file, pages: [InvoiceDocument.Page(kind: .pdf, data: Data(count: 10))])
        }
        #expect(viewModel.pendingRoute == .newInvoice(source: .file, pageCount: 1))
    }

    @Test func twentyMegabytesInAllPassAndOneByteMoreIsRefused() async {
        let viewModel = await make()
        viewModel.captured(document(.camera, bytes: [12_000_000, 8_000_000]))
        #expect(viewModel.pendingRoute == .newInvoice(source: .camera, pageCount: 2), "Exactly 20 MB")
        viewModel.clearPendingRoute()

        viewModel.captured(document(.camera, bytes: [12_000_000, 8_000_001]))
        #expect(viewModel.pendingRoute == nil)
        #expect(viewModel.message == .init(title: "The pages are over 20 MB", detail: "Use fewer pages."))
        viewModel.clearMessage()

        viewModel.captured(document(.file, bytes: [20_000_001]))
        #expect(viewModel.message == .init(title: "This file is over 20 MB", detail: "Choose a smaller PDF or image."))
    }

    @Test func aCaptureThatFailsSaysWhyAndGoesNowhere() async {
        let viewModel = await make()
        viewModel.takePhoto()
        await viewModel.capture { () async throws(InvoiceCaptureError) in throw .unreadable(.camera) }
        #expect(!viewModel.isScannerPresented)
        #expect(viewModel.pendingRoute == nil)
        #expect(viewModel.message == .init(title: "Couldn't read the pages", detail: "Try again."))

        viewModel.failed(.unreadable(.file))
        #expect(viewModel.message?.title == "Couldn't open this file")
        #expect(viewModel.message?.detail == "Try again, or choose another one.")
        await viewModel.capture { () async throws(InvoiceCaptureError) in throw .tooLarge(.file) }
        #expect(viewModel.message?.title == "This file is over 20 MB")

        viewModel.takePhoto()
        viewModel.failed(.scannerFailed)
        #expect(!viewModel.isScannerPresented)
        #expect(viewModel.message == .init(title: "Couldn't scan", detail: "Upload a PDF or image instead."))
    }

    @Test func noPagesGoNowhereAndSayNothing() async {
        let viewModel = await make()
        viewModel.captured(InvoiceDocument(source: .camera, pages: []))
        #expect(viewModel.pendingRoute == nil)
        #expect(viewModel.message == nil)
    }

    @Test func thePickersWaitWhilePagesAreBeingPrepared() async {
        let viewModel = await make(canScan: false)
        await viewModel.capture { () async throws(InvoiceCaptureError) in
            #expect(viewModel.isPreparing)
            viewModel.takePhoto()
            viewModel.uploadFile()
            return self.document(.camera, bytes: [10])
        }
        #expect(!viewModel.isPhotoPickerPresented)
        #expect(!viewModel.isFileImporterPresented)
        #expect(!viewModel.isPreparing)
    }

    @Test func theCopyFollowsThePRD() {
        #expect(ReceiveViewModel.reassurance == "Nothing affects inventory until you confirm.")
        #expect(ReceiveViewModel.continueTitle == "Continue reviewing")
    }
}
