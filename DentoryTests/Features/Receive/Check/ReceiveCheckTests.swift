import Foundation
import Testing
@testable import Dentory

/// MS-163: captured photos are checked on the device before Review invoice uploads them. A sharp photo goes straight
/// on and a PDF is never checked; a blurry or dark one opens the sheet, where Retake opens the same picker again, Use
/// anyway sends the pages on, and closing it drops them, with nothing uploaded before an answer.
struct ReceiveCheckTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        _ checker: FakeInvoicePageChecker, canScan: Bool = true, analytics: Analytics = NoopAnalytics()
    ) -> ReceiveViewModel {
        ReceiveViewModel(
            repository: FakeReceiveRepository(), cache: InMemoryResponseCache(), formatters: formatters,
            clinicID: Session.demo.clinicID, canScan: canScan, checker: checker, analytics: analytics
        )
    }

    /// JPEG pages told apart by their size.
    private func photos(_ source: InvoiceDocument.Source = .camera, count: Int = 1) -> InvoiceDocument {
        InvoiceDocument(
            source: source, pages: (1...count).map { InvoiceDocument.Page(kind: .jpeg, data: Data(count: $0)) }
        )
    }

    private func capture(_ document: InvoiceDocument, with viewModel: ReceiveViewModel) async {
        await viewModel.capture(from: document.source) { () async throws(InvoiceCaptureError) in document }
    }

    // MARK: - What is checked

    @Test func sharpPhotosAreEachCheckedAndGoStraightToReviewInvoice() async {
        let checker = FakeInvoicePageChecker()
        let viewModel = make(checker)
        let scanned = photos(count: 3)
        await capture(scanned, with: viewModel)
        #expect(checker.checkedPages == scanned.pages.map(\.data))
        #expect(viewModel.check == nil)
        #expect(viewModel.pendingRoute == .newInvoice(scanned))
    }

    @Test func aPDFIsNeverChecked() async {
        let checker = FakeInvoicePageChecker(problems: [.blurry])
        let viewModel = make(checker)
        let pdf = InvoiceDocument(source: .file, pages: [InvoiceDocument.Page(kind: .pdf, data: Data(count: 10))])
        await capture(pdf, with: viewModel)
        #expect(checker.checkedPages.isEmpty)
        #expect(viewModel.pendingRoute == .newInvoice(pdf))
    }

    @Test func pagesRefusedForTheirSizeOrCountAreNotChecked() async {
        let checker = FakeInvoicePageChecker(problems: [.blurry])
        let viewModel = make(checker)
        await capture(photos(count: 21), with: viewModel)
        #expect(checker.checkedPages.isEmpty)
        #expect(viewModel.check == nil)
        #expect(viewModel.message?.title == "Up to 20 pages per invoice")
    }

    @Test func theOptionUsedStaysBusyWhileThePagesAreChecked() async {
        let checker = FakeInvoicePageChecker()
        let viewModel = make(checker)
        var busy: [InvoiceDocument.Source?] = []
        checker.whileChecking = { busy.append(viewModel.preparing) }
        await capture(photos(.file), with: viewModel)
        #expect(busy == [.file])
        #expect(viewModel.preparing == nil)
        #expect(!viewModel.isPreparing)
    }

    // MARK: - The sheet

    @Test func aBlurryPhotoOpensTheSheetAndNothingGoesOn() async {
        let viewModel = make(FakeInvoicePageChecker(problems: [.blurry]))
        let scanned = photos()
        await capture(scanned, with: viewModel)
        #expect(viewModel.check == ReceiveCheck(document: scanned, page: 1, problem: .blurry))
        #expect(viewModel.pendingRoute == nil, "Nothing is uploaded before an answer")
        #expect(viewModel.message == nil)
        #expect(viewModel.check?.title == "This photo is hard to read")
        #expect(viewModel.check?.retakeTitle == "Retake")
    }

    @Test func theFirstUnreadablePageIsNamedWhenThereAreSeveralAndTheRestAreNotChecked() async {
        let checker = FakeInvoicePageChecker(problems: [nil, .dark, .blurry])
        let viewModel = make(checker)
        await capture(photos(count: 3), with: viewModel)
        #expect(viewModel.check?.page == 2)
        #expect(viewModel.check?.title == "Page 2 is too dark")
        #expect(checker.checkedPages.count == 2)
    }

    @Test func retakeOpensTheScannerAgainOnceTheSheetHasClosed() async {
        let analytics = SpyAnalytics()
        let viewModel = make(FakeInvoicePageChecker(problems: [.blurry]), analytics: analytics)
        viewModel.takePhoto()
        await capture(photos(), with: viewModel)
        #expect(!viewModel.isScannerPresented)

        viewModel.retake()
        #expect(viewModel.check == nil)
        #expect(!viewModel.isScannerPresented, "Not while the sheet is still closing")
        #expect(analytics.events == [.pageCheckRetaken(reason: .blurry)])
        viewModel.checkClosed()
        #expect(viewModel.isScannerPresented)
        #expect(viewModel.pendingRoute == nil, "The pages are dropped")
    }

    @Test func retakeOpensPhotosAgainWithoutAScanner() async {
        let viewModel = make(FakeInvoicePageChecker(problems: [.dark]), canScan: false)
        await capture(photos(), with: viewModel)
        viewModel.retake()
        viewModel.checkClosed()
        #expect(viewModel.isPhotoPickerPresented)
        #expect(!viewModel.isScannerPresented)
    }

    @Test func chooseAnotherOpensFilesAgain() async {
        let analytics = SpyAnalytics()
        let viewModel = make(FakeInvoicePageChecker(problems: [.dark]), analytics: analytics)
        await capture(photos(.file), with: viewModel)
        #expect(viewModel.check?.retakeTitle == "Choose another")
        viewModel.retake()
        viewModel.checkClosed()
        #expect(viewModel.isFileImporterPresented)
        #expect(analytics.events == [.pageCheckRetaken(reason: .dark)])
    }

    @Test func useAnywaySendsThePagesOnToReviewInvoice() async {
        let analytics = SpyAnalytics()
        let viewModel = make(FakeInvoicePageChecker(problems: [.dark]), analytics: analytics)
        let scanned = photos(count: 2)
        await capture(scanned, with: viewModel)
        viewModel.useAnyway()
        #expect(viewModel.check == nil)
        #expect(analytics.events == [.pageCheckOverruled(reason: .dark)])
        viewModel.checkClosed()
        #expect(viewModel.pendingRoute == .newInvoice(scanned))
        #expect(!viewModel.isScannerPresented)
    }

    @Test func closingTheSheetWithoutAnAnswerDropsThePages() async {
        let analytics = SpyAnalytics()
        let viewModel = make(FakeInvoicePageChecker(problems: [.blurry]), analytics: analytics)
        await capture(photos(), with: viewModel)
        viewModel.check = nil
        viewModel.checkClosed()
        #expect(viewModel.pendingRoute == nil)
        #expect(!viewModel.isScannerPresented)
        #expect(!viewModel.isPhotoPickerPresented)
        #expect(!viewModel.isFileImporterPresented)
        #expect(analytics.events.isEmpty)

        viewModel.retake()
        viewModel.useAnyway()
        #expect(analytics.events.isEmpty, "No sheet, no answer")
    }

    // MARK: - Copy

    @Test func theSheetSaysWhatTheTicketSays() {
        func check(
            _ source: InvoiceDocument.Source, pages: Int, page: Int = 1, _ problem: InvoicePageProblem
        ) -> ReceiveCheck {
            ReceiveCheck(document: photos(source, count: pages), page: page, problem: problem)
        }
        #expect(check(.camera, pages: 1, .blurry).title == "This photo is hard to read")
        #expect(check(.camera, pages: 3, page: 2, .blurry).title == "Page 2 is hard to read")
        #expect(check(.camera, pages: 1, .dark).title == "This photo is too dark")
        #expect(check(.camera, pages: 2, page: 2, .dark).title == "Page 2 is too dark")
        #expect(check(.file, pages: 1, .blurry).title == "This image is hard to read")
        #expect(check(.file, pages: 1, .dark).title == "This image is too dark")

        #expect(check(.camera, pages: 1, .blurry).message
            == "The text looks blurry, so lines could be missed. Hold the phone steady over the page, in good light.")
        #expect(check(.camera, pages: 1, .dark).message
            == "Lines could be missed. Retake it in better light or with the flash on.")
        #expect(check(.file, pages: 1, .blurry).message == "The text looks blurry, so lines could be missed.")
        #expect(check(.file, pages: 1, .dark).message == "It is too dark, so lines could be missed.")

        #expect(check(.camera, pages: 1, .dark).retakeTitle == "Retake")
        #expect(check(.file, pages: 1, .dark).retakeTitle == "Choose another")
        #expect(ReceiveCheck.useAnywayTitle == "Use anyway")
    }
}
