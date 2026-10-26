import Foundation
import Observation

/// Review invoice (f23, f38; PRD §6.5 Reading state; Appendix B `invoice`), Admin only, up to its reading (MS-129). For
/// pages just captured it uploads them, creates the invoice and asks the server to read it (flow step 1); for an
/// invoice opened from Receive delivery it follows the reading already under way. Then the read header (the lines to
/// review arrive with MS-130), or the failure with a clearer photo or receiving by hand. The admin may leave at any
/// point: the upload carries on, the server reads on, and the bell and a push say when the delivery is ready (MS-144).
/// The lines it shows are in `InvoiceViewModel+Copy.swift`.
@MainActor
@Observable
final class InvoiceViewModel {
    enum State: Equatable {
        /// Opening an invoice: waiting for its first answer.
        case loading
        /// The invoice could not be opened.
        case loadFailed(AppError)
        /// The captured pages are going up.
        case uploading
        /// The pages could not be uploaded, or the invoice created.
        case uploadFailed(AppError)
        /// Being read on the server.
        case reading
        /// Read and waiting for review.
        case ready
        /// The reading failed.
        case failed
        /// Received or set aside since it was opened.
        case closed
    }

    /// How often the screen asks how the reading goes.
    static let pollInterval: Duration = .seconds(2)
    /// How many times a reading that has not started is asked for (a request lost on the way).
    static let maxReadingRequests = 3

    let invoiceID: UUID
    let formatters: ClinicFormatters
    private(set) var state: State
    private(set) var invoice: InvoiceSummary?
    /// Grows with each Try again, so the screen's task runs `load()` again.
    private(set) var attempt = 0

    private let document: InvoiceDocument?
    private let repository: InvoiceRepository
    private let clinicID: UUID
    private let pause: @Sendable (Duration) async throws -> Void
    /// The upload and the invoice's creation, which carry on when the admin leaves the screen.
    private var submission: Task<Void, Never>?
    /// Pages just captured that are still to go up. Cleared when their upload starts, so a screen that appears again
    /// never sends them a second time; set again only by Try again after a failed upload, and cleared for good by
    /// Receive manually instead.
    private var needsUpload: Bool
    private var isCreated: Bool
    private var readingRequests = 0

    /// Pages just captured (`ReceiveRoute.newInvoice`): they become the invoice `document.id`.
    convenience init(
        document: InvoiceDocument, repository: InvoiceRepository, formatters: ClinicFormatters, clinicID: UUID,
        pause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(
            invoiceID: document.id, document: document, repository: repository, formatters: formatters,
            clinicID: clinicID, pause: pause
        )
    }

    /// An invoice already uploaded (`ReceiveRoute.invoice`).
    convenience init(
        invoiceID: UUID, repository: InvoiceRepository, formatters: ClinicFormatters, clinicID: UUID,
        pause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(
            invoiceID: invoiceID, document: nil, repository: repository, formatters: formatters, clinicID: clinicID,
            pause: pause
        )
    }

    private init(
        invoiceID: UUID, document: InvoiceDocument?, repository: InvoiceRepository, formatters: ClinicFormatters,
        clinicID: UUID, pause: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.invoiceID = invoiceID
        self.document = document
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
        self.pause = pause
        needsUpload = document != nil
        isCreated = document == nil
        state = document == nil ? .loading : .uploading
    }

    /// Uploads captured pages once (again after Try again), then follows the reading until it ends or the screen goes.
    func load() async {
        if needsUpload, let document {
            needsUpload = false
            submission = Task { await self.submit(document) }
        }
        await submission?.value
        await follow()
    }

    /// Try again after a failed upload (the same pages, under the same invoice) or a failed first load.
    func retry() {
        switch state {
        case .uploadFailed:
            needsUpload = true
            state = .uploading
        case .loadFailed:
            state = .loading
        default:
            return
        }
        attempt += 1
    }

    /// Receive manually instead: the upload stops for good, and once it has stopped the invoice is set aside, so its
    /// reading, when it ends, raises no delivery waiting for review to be received a second time. Pages that had not
    /// become an invoice show as set aside when the admin comes back; an invoice shows what the server says of it. Best
    /// effort: the admin is on Receive manually by then, and an invoice that could not be set aside (no connection)
    /// stays in Continue reviewing until it is discarded there (MS-130), so nothing is shown for it.
    func setAside() {
        needsUpload = false
        let submission = submission
        submission?.cancel()
        if !isCreated {
            state = .closed
        }
        let repository = repository
        let invoiceID = invoiceID
        Task {
            await submission?.value
            try? await repository.discard(invoiceID: invoiceID)
        }
    }

    /// Runs with the state already uploading (the captured pages, or Try again after a failed upload).
    private func submit(_ document: InvoiceDocument) async {
        defer { submission = nil }
        do {
            try await repository.upload(document, clinicID: clinicID)
            try Task.checkCancellation()
            let created = try await repository.create(document, clinicID: clinicID)
            isCreated = true
            // Set aside meanwhile: `setAside()` discards the invoice now that it exists.
            guard !Task.isCancelled else { return }
            show(created)
            await requestReading()
        } catch {
            if !Task.isCancelled {
                state = .uploadFailed(AppError(error))
            }
        }
    }

    /// Asks how the reading goes until it ends; a reading not started yet is asked for again. A question that fails
    /// while the invoice is read waits for the next one.
    private func follow() async {
        while !Task.isCancelled, state == .loading || state == .reading {
            do {
                let current = try await repository.invoice(id: invoiceID)
                show(current)
                if current.status == .reading, !current.readingStarted {
                    await requestReading()
                }
            } catch {
                if state == .loading {
                    state = .loadFailed(AppError(error))
                    return
                }
            }
            guard state == .reading else { return }
            do {
                try await pause(Self.pollInterval)
            } catch {
                return
            }
        }
    }

    private func requestReading() async {
        guard readingRequests < Self.maxReadingRequests else { return }
        readingRequests += 1
        try? await repository.startReading(invoiceID: invoiceID)
    }

    private func show(_ invoice: InvoiceSummary) {
        self.invoice = invoice
        state = switch invoice.status {
        case .reading: .reading
        case .ready: .ready
        case .failed: .failed
        case .confirmed, .discarded: .closed
        }
    }
}
