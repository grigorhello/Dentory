import Foundation
import Observation

/// Receive delivery (f22; PRD §6.5; Appendix B `receive`), Admin only: Take a photo (the document scanner, or Photos
/// where the device has none), Upload PDF or image, and Receive manually; above "Waiting for delivery", the invoices
/// to continue reviewing, a reading that failed among them; and the lines marked Ordered, for reference only. The
/// last lists are served from the cache while fresh ones load or the network is gone (MS-108). Captured photos are
/// checked on the device before they go on, and one that looks unreadable asks for a retake (MS-163). Nothing here
/// changes stock. The lines are in `ReceiveViewModel+Copy.swift`.
@MainActor
@Observable
final class ReceiveViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A toast the screen shows.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }

    private(set) var state: LoadState = .loading
    private(set) var overview: ReceiveOverview?
    /// VisionKit's document scanner: Take a photo on a device that has it.
    var isScannerPresented = false
    /// Photos: Take a photo where the device has no scanner.
    var isPhotoPickerPresented = false
    /// Files: Upload PDF or image.
    var isFileImporterPresented = false
    /// The option whose pages are being prepared and checked, which shows it is busy; a second capture waits for it.
    private(set) var preparing: InvoiceDocument.Source?
    /// A captured page that looks unreadable: the sheet asking for a retake (MS-163), closed by setting it to nil.
    var check: ReceiveCheck?
    /// A check found while the scanner's cover is still on screen or going away; it becomes `check` once the cover has
    /// gone, since SwiftUI drops a sheet asked for while a full-screen cover is still being dismissed.
    private var pendingCheck: ReceiveCheck?
    /// From asking for the scanner until its cover has gone (`scannerDismissed`), after a scan, Cancel or a failure.
    private var isScannerOnScreen = false
    private(set) var message: Message?
    /// Where the screen goes next (captured pages, or an invoice to continue); the view pushes it and clears it.
    private(set) var pendingRoute: ReceiveRoute?
    /// The check's answer, carried out once its sheet has closed, so the picker or Review invoice opens after it.
    private var checkAnswer: CheckAnswer?

    private enum CheckAnswer {
        case retake(InvoiceDocument.Source)
        case useAnyway(InvoiceDocument)
    }

    let formatters: ClinicFormatters
    private let repository: ReceiveRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let canScan: Bool
    private let checker: InvoicePageChecker
    private let analytics: Analytics

    init(
        repository: ReceiveRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID,
        canScan: Bool, checker: InvoicePageChecker, analytics: Analytics
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.canScan = canScan
        self.checker = checker
        self.analytics = analytics
        overview = cache.load(ReceiveOverview.self, for: Self.cacheKey(clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ReceiveRepository.overview", clinicID: clinicID)
    }

    var isPreparing: Bool { preparing != nil }

    /// Invoices being read, ready to review or whose reading failed, newest first ("Continue reviewing").
    var invoices: [PendingInvoice] { overview?.invoices ?? [] }

    /// Lines marked Ordered ("Waiting for delivery"); the section hides when there are none.
    var waiting: [WaitingItem] { overview?.waiting ?? [] }

    /// Reads the lists; a reload that fails keeps the last ones on screen.
    func load() async {
        do {
            let fresh = try await repository.overview(clinicID: clinicID)
            cache.store(fresh, for: Self.cacheKey(clinicID))
            overview = fresh
            state = .loaded
        } catch {
            state = overview == nil ? .failed(AppError(error)) : .loaded
        }
    }

    /// Continue reviewing: Review invoice, which follows a reading under way, shows the invoice read, or says the
    /// reading failed with Try again and Receive manually.
    func continueReviewing(_ invoice: PendingInvoice) {
        pendingRoute = .invoice(invoice.id)
    }

    // MARK: - Capture

    /// Take a photo: the scanner, or Photos where the device has no scanner.
    func takePhoto() {
        guard !isPreparing, pendingCheck == nil else { return }
        if canScan {
            isScannerOnScreen = true
            isScannerPresented = true
        } else {
            isPhotoPickerPresented = true
        }
    }

    /// Upload PDF or image: Files, for a PDF, JPG, PNG or HEIC.
    func uploadFile() {
        guard !isPreparing, pendingCheck == nil else { return }
        isFileImporterPresented = true
    }

    /// Turns what the scanner or Photos (`source` camera) or Files handed over into a document with `prepare` and
    /// checks its photos, then sends it on to Review invoice, asks for a retake, or says why it cannot go.
    func capture(
        from source: InvoiceDocument.Source, _ prepare: () async throws(InvoiceCaptureError) -> InvoiceDocument
    ) async {
        isScannerPresented = false
        guard preparing == nil else { return }
        preparing = source
        defer { preparing = nil }
        do {
            let document = try await prepare()
            if let check = await firstUnreadablePage(in: document) {
                show(check)
            } else {
                captured(document)
            }
        } catch {
            failed(error)
        }
    }

    /// The first JPEG page that looks unreadable, among pages fit to go otherwise; a PDF is never checked (MS-163).
    private func firstUnreadablePage(in document: InvoiceDocument) async -> ReceiveCheck? {
        guard !document.pages.isEmpty, !document.isTooLarge, !document.hasTooManyPages else { return nil }
        for (index, page) in document.pages.enumerated() where page.kind == .jpeg {
            if let problem = await checker.problem(inJPEG: page.data) {
                return ReceiveCheck(document: document, page: index + 1, problem: problem)
            }
        }
        return nil
    }

    /// Pages over 20 MB in all, or more than 20 of them, are refused; otherwise they go to Review invoice, which
    /// uploads and reads them (MS-129).
    func captured(_ document: InvoiceDocument) {
        isScannerPresented = false
        guard !document.pages.isEmpty else { return }
        guard !document.isTooLarge else {
            failed(.tooLarge(document.source))
            return
        }
        guard !document.hasTooManyPages else {
            failed(.tooManyPages)
            return
        }
        pendingRoute = .newInvoice(document)
    }

    /// The scanner stopped, or the photos or the file could not be read or were too large: the screen says so.
    func failed(_ error: InvoiceCaptureError) {
        isScannerPresented = false
        message = Self.message(for: error)
    }

    // MARK: - Check

    /// The sheet opens now, or once the scanner's cover has gone.
    private func show(_ check: ReceiveCheck) {
        if isScannerOnScreen {
            pendingCheck = check
        } else {
            self.check = check
        }
    }

    /// The scanner's cover has finished going away, after a scan, Cancel or a failure: a check found meanwhile opens.
    func scannerDismissed() {
        isScannerOnScreen = false
        guard let pendingCheck else { return }
        self.pendingCheck = nil
        check = pendingCheck
    }

    /// Retake, or Choose another for a file: the pages are dropped, and once the sheet has closed the scanner, Photos
    /// or Files opens again.
    func retake() {
        guard let check else { return }
        analytics.track(.pageCheckRetaken(reason: check.problem))
        checkAnswer = .retake(check.document.source)
        self.check = nil
    }

    /// Use anyway: once the sheet has closed, the pages go on to Review invoice as they are.
    func useAnyway() {
        guard let check else { return }
        analytics.track(.pageCheckOverruled(reason: check.problem))
        checkAnswer = .useAnyway(check.document)
        self.check = nil
    }

    /// The check's sheet has closed: Retake's picker or Use anyway's Review invoice opens; closed without an answer,
    /// the captured pages are dropped.
    func checkClosed() {
        let answer = checkAnswer
        checkAnswer = nil
        check = nil
        switch answer {
        case .retake(.camera): takePhoto()
        case .retake(.file): uploadFile()
        case .useAnyway(let document): captured(document)
        case nil: break
        }
    }

    func clearMessage() {
        message = nil
    }

    func clearPendingRoute() {
        pendingRoute = nil
    }
}
