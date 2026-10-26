import Foundation
import Observation

/// Review invoice (f23, f38; PRD §6.5 Reading state, Review invoice and Confirm; Appendix B `invoice`), Admin only. For
/// pages just captured it uploads them, creates the invoice and asks the server to read it (flow step 1, MS-129); for
/// an invoice opened from Receive delivery or Activity it follows the reading already under way. Then the read header
/// with the lines to review and Confirm & receive (`review`, MS-130, MS-131), the lines of a delivery received already,
/// read-only, or the failure with a clearer photo or receiving by hand. The admin may leave at any point: the upload
/// carries on, the server reads on, and the bell and a push say when the delivery is ready (MS-144). The header's menu
/// discards the invoice (`InvoiceViewModel+Discard.swift`). The states are in `InvoiceViewModel+State.swift`, the lines
/// it shows in `InvoiceViewModel+Copy.swift`.
@MainActor
@Observable
final class InvoiceViewModel {
    let invoiceID: UUID
    let formatters: ClinicFormatters
    private(set) var state: State
    private(set) var invoice: InvoiceSummary?
    /// The lines to review once the invoice is read (MS-130), or a received delivery's, read-only (MS-131).
    private(set) var review: InvoiceReviewViewModel?
    /// Grows with each Try again, so the screen's task runs `load()` again.
    private(set) var attempt = 0
    /// The question Discard invoice asks, from the header's "…" menu.
    var isConfirmingDiscard = false
    /// Set once the invoice is discarded: the screen goes back to Receive delivery with the toast.
    private(set) var discarded: Message?
    /// A discard that failed; the screen shows it as a toast.
    private(set) var generalError: AppError?
    let discardGuard = SubmitGuard()

    private let document: InvoiceDocument?
    private let repository: InvoiceRepository
    private let clinicID: UUID
    private let analytics: Analytics
    private let pause: @Sendable (Duration) async throws -> Void
    /// The upload and the invoice's creation, which carry on when the admin leaves the screen.
    private var submission: Task<Void, Never>?
    /// Pages just captured that are still to go up. Cleared when their upload starts, so a screen that appears again
    /// never sends them a second time; set again only by Try again after a failed upload, and cleared for good by
    /// Receive manually instead.
    private var needsUpload: Bool
    private var isCreated: Bool
    private var readingRequests = 0
    /// Try again after a failed reading: the set-aside every tap waits for.
    private var settingAside: Task<Void, Never>?

    /// Pages just captured (`ReceiveRoute.newInvoice`): they become the invoice `document.id`.
    convenience init(
        document: InvoiceDocument, repository: InvoiceRepository, formatters: ClinicFormatters, clinicID: UUID,
        analytics: Analytics = NoopAnalytics(),
        pause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(
            invoiceID: document.id, document: document, repository: repository, formatters: formatters,
            clinicID: clinicID, analytics: analytics, pause: pause
        )
    }

    /// An invoice already uploaded (`ReceiveRoute.invoice`).
    convenience init(
        invoiceID: UUID, repository: InvoiceRepository, formatters: ClinicFormatters, clinicID: UUID,
        analytics: Analytics = NoopAnalytics(),
        pause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(
            invoiceID: invoiceID, document: nil, repository: repository, formatters: formatters, clinicID: clinicID,
            analytics: analytics, pause: pause
        )
    }

    private init(
        invoiceID: UUID, document: InvoiceDocument?, repository: InvoiceRepository, formatters: ClinicFormatters,
        clinicID: UUID, analytics: Analytics, pause: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.invoiceID = invoiceID
        self.document = document
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
        self.analytics = analytics
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

    /// Reads the invoice again (back in the foreground, a choice or a discard the server refused): its lines as they
    /// are now, or the news that it was received, set aside or (by Undo) put back meanwhile. A read that fails keeps
    /// what is shown.
    func refresh() async {
        guard state == .ready || state == .received || state == .failed else { return }
        guard let current = try? await repository.invoice(id: invoiceID) else { return }
        show(current)
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

    /// Receive manually instead, and Receive manually after a failed reading: the upload stops for good, and once it
    /// has stopped the invoice is set aside, so its reading, when it ends, raises no delivery waiting for review to be
    /// received a second time, and a reading that failed leaves Continue reviewing. Pages that had not become an
    /// invoice, and an invoice whose reading failed, show as set aside when the admin comes back; an invoice being read
    /// shows what the server says of it. Best effort: the admin is on Receive manually by then, and an invoice that
    /// could not be set aside (no connection) stays in Continue reviewing until it is discarded there (MS-130), so
    /// nothing is shown for it.
    func setAside() {
        needsUpload = false
        let submission = submission
        submission?.cancel()
        if !isCreated || state == .failed {
            state = .closed
        }
        let repository = repository
        let invoiceID = invoiceID
        let clinicID = clinicID
        Task {
            await submission?.value
            try? await repository.discard(invoiceID: invoiceID, clinicID: clinicID)
        }
    }

    /// Try again after a failed reading, for a clearer photo or another file on Receive delivery's options: the invoice
    /// that could not be read is set aside first, so the options' list, loaded again as they come back, does not show
    /// it beside the next try. Returns once the server has answered, whatever it said: an invoice it could not set
    /// aside stays listed and opens this failure again. Taps made meanwhile wait for the same answer.
    func setAsideToCaptureAgain() async {
        guard state == .failed else { return }
        if settingAside == nil {
            let repository = repository
            let invoiceID = invoiceID
            let clinicID = clinicID
            settingAside = Task { try? await repository.discard(invoiceID: invoiceID, clinicID: clinicID) }
        }
        await settingAside?.value
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

    /// The invoice as the server has it: lines to review, or a delivery received, whose lines are shown read-only.
    private func show(_ invoice: InvoiceSummary) {
        self.invoice = invoice
        state = switch invoice.status {
        case .reading: .reading
        case .ready: .ready
        case .failed: .failed
        case .confirmed: .received
        case .discarded: .closed
        }
        guard invoice.status == .ready || invoice.status == .confirmed else { return }
        if let review, review.isReceived == (invoice.status == .confirmed) {
            review.update(with: invoice.lines)
        } else {
            review = InvoiceReviewViewModel(
                invoice: invoice, repository: repository, formatters: formatters(for: invoice), analytics: analytics,
                reload: { [weak self] in await self?.refresh() }
            )
        }
    }

    /// Discard invoice: the invoice is set aside and its pages deleted; the screen leaves with the toast. One received
    /// meanwhile on another device is refused with the server's sentence, and shows as received.
    func discard() async {
        await discardGuard.run {
            review?.dropPendingSaves()
            do {
                try await repository.discard(invoiceID: invoiceID, clinicID: clinicID)
                isConfirmingDiscard = false
                state = .closed
                discarded = Message(title: Self.discardedTitle, detail: header)
            } catch {
                // Not queued offline: a lost connection reads "Couldn't save. Try again."
                let error = AppError(error)
                generalError = error == .network ? .unknown("No connection") : error
                guard case .validation = error else { return }
                isConfirmingDiscard = false
                await refresh()
            }
        }
    }

    func clearGeneralError() {
        generalError = nil
    }
}
