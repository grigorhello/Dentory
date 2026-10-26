import Foundation
import Observation

/// Receive delivery (f22; PRD §6.5; Appendix B `receive`), Admin only: Take a photo (the document scanner, or Photos
/// where the device has none), Upload PDF or image, and Receive manually; above "Waiting for delivery", the invoices
/// to continue reviewing; and the lines marked Ordered, for reference only. The last lists are served from the cache
/// while fresh ones load or the network is gone (MS-108). Nothing here changes stock. The lines are in
/// `ReceiveViewModel+Copy.swift`.
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
    /// While captured pages are being prepared, so a second capture waits for the first.
    private(set) var isPreparing = false
    private(set) var message: Message?
    /// Where captured pages go next; the view pushes it and clears it.
    private(set) var pendingRoute: ReceiveRoute?

    let formatters: ClinicFormatters
    private let repository: ReceiveRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let canScan: Bool

    init(
        repository: ReceiveRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID,
        canScan: Bool
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.canScan = canScan
        overview = cache.load(ReceiveOverview.self, for: Self.cacheKey(clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ReceiveRepository.overview", clinicID: clinicID)
    }

    /// Invoices being read or ready to review, newest first ("Continue reviewing").
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

    // MARK: - Capture

    /// Take a photo: the scanner, or Photos where the device has no scanner.
    func takePhoto() {
        guard !isPreparing else { return }
        if canScan {
            isScannerPresented = true
        } else {
            isPhotoPickerPresented = true
        }
    }

    /// Upload PDF or image: Files, for a PDF, JPG, PNG or HEIC.
    func uploadFile() {
        guard !isPreparing else { return }
        isFileImporterPresented = true
    }

    /// Turns what the scanner, Photos or Files handed over into a document with `prepare`, then sends it on to Review
    /// invoice, or says why it cannot go.
    func capture(_ prepare: () async throws(InvoiceCaptureError) -> InvoiceDocument) async {
        isScannerPresented = false
        guard !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }
        do {
            captured(try await prepare())
        } catch {
            failed(error)
        }
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

    func clearMessage() {
        message = nil
    }

    func clearPendingRoute() {
        pendingRoute = nil
    }
}
