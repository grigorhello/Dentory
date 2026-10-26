import Foundation
import Observation

/// Review invoice once read (f23, f38; PRD §6.5 Review invoice and Confirm; Appendix B `invoice.line[n]`,
/// `invoice.summary`, `invoice.confirm`; Appendix C `match`, `newProduct`), Admin only: each line with its state and
/// the choice it waits for. Yes, match, Ignore and a resolved line's badge (back to the state it was read in) are saved
/// at once; Pick existing and Pick product open Which product is this?; Add new and No, create new open New product;
/// the lot and expiry month of a Matched or Created line are saved a moment after the last change
/// (`InvoiceReviewViewModel+Batch.swift`). Every choice is saved on the server, so the admin can leave and come back.
/// Confirm & receive waits for every line to be resolved, then receives the delivery (`receipt`, MS-131); a received
/// invoice opened later shows its lines read-only. Its sheet, choices and toasts are in
/// `InvoiceReviewViewModel+Types.swift`, the words in `InvoiceReviewViewModel+Copy.swift`.
@MainActor
@Observable
final class InvoiceReviewViewModel {
    private(set) var lines: [InvoiceLine]
    var sheet: Sheet?
    /// Lines whose choice is being saved; their buttons wait meanwhile.
    private(set) var savingLineIDs: Set<UUID> = []
    private(set) var message: Message?
    /// A choice the server refused, or a save that failed; the screen shows it as a toast.
    private(set) var generalError: AppError?
    /// Read-only mode (MS-142), set by the screen: a lot or expiry stays as it is, and the screen opens the read-only
    /// sheet.
    var isReadOnly = false
    /// The changes read-only mode refused; the screen shows the sheet for each.
    private(set) var refusedChanges = 0
    /// Lines whose lot or expiry changed since it was last saved, and their saves under way; a reload keeps the lines'
    /// lots and expiries over the server's (`InvoiceReviewViewModel+Batch.swift`).
    var unsavedBatchIDs: Set<UUID> = []
    var batchSaves: [UUID: Task<Void, Never>] = [:]

    let invoiceID: UUID
    /// Received already (MS-131): the lines show what came in, and none of them changes.
    let isReceived: Bool
    /// Confirm & receive and its Undo (MS-131).
    let receipt: InvoiceReceiptViewModel
    /// In the invoice's own currency.
    let formatters: ClinicFormatters
    private let repository: InvoiceLinesRepository & InvoiceReceivingRepository
    private let saveDelay: Duration
    /// Reads the invoice again after a refusal: the line, or the whole invoice, may have changed meanwhile.
    private let reload: @MainActor () async -> Void
    private let confirmGuard = SubmitGuard()

    init(
        invoice: InvoiceSummary, repository: InvoiceLinesRepository & InvoiceReceivingRepository,
        formatters: ClinicFormatters, analytics: Analytics, saveDelay: Duration = .milliseconds(600),
        reload: @escaping @MainActor () async -> Void
    ) {
        invoiceID = invoice.id
        lines = invoice.lines
        isReceived = invoice.status == .confirmed
        receipt = InvoiceReceiptViewModel(
            invoice: invoice, repository: repository, analytics: analytics, clock: formatters.clock, reload: reload
        )
        self.repository = repository
        self.formatters = formatters
        self.saveDelay = saveDelay
        self.reload = reload
    }

    /// The lines as the server has them now; a lot or expiry not saved yet stays as typed.
    func update(with fresh: [InvoiceLine]) {
        lines = fresh.map(keepingUnsavedBatch)
    }

    func isSaving(_ line: InvoiceLine) -> Bool {
        savingLineIDs.contains(line.id)
    }

    // MARK: - Choices

    /// What a line's buttons do: Yes, match and Ignore save at once, the others open their sheet.
    func perform(_ choice: Choice, on line: InvoiceLine) async {
        switch choice {
        case .yesMatch:
            guard let productID = line.suggestedProductID else { return }
            await save(line) { try await $0.matchLine(line.id, to: productID) }
        case .ignore:
            await save(line) { try await $0.skipLine(line.id) }
        case .createNew, .addNew:
            sheet = .newProduct(line)
        case .pickExisting, .pickProduct:
            sheet = .match(line)
        }
    }

    /// A resolved line's badge, or Undo on a skipped one: back to the state it was read in.
    func reopen(_ line: InvoiceLine) async {
        guard canReopen(line) else { return }
        await save(line) { try await $0.reopenLine(line.id) }
    }

    /// The badge reopens a line the admin resolved, until the invoice is received.
    func canReopen(_ line: InvoiceLine) -> Bool { !isReceived && line.canReopen }

    /// Which product is this?: the line is Matched to the product picked.
    func choose(_ productID: UUID, for line: InvoiceLine) async {
        sheet = nil
        await save(line) { try await $0.matchLine(line.id, to: productID) }
    }

    /// Create and use for this line: the sheet closes at once (so the button cannot create a second product) and the
    /// line becomes the product just created. Its link is tried up to three times, so a connection lost between the two
    /// steps does not leave the product without its line.
    func productCreated(_ productID: UUID, for line: InvoiceLine) async {
        sheet = nil
        let created = await save(line, attempts: 3) { try await $0.createLine(line.id, as: productID) }
        if let created {
            message = Message(title: "Product created", detail: Self.createdDetail(created))
        }
    }

    // MARK: - Confirm & receive (MS-131)

    /// Every line resolved: Matched, Created or Skipped.
    var allResolved: Bool { !lines.isEmpty && lines.allSatisfy(\.isResolved) }

    /// While the delivery is received: the button waits.
    var isConfirming: Bool { confirmGuard.isBusy }

    /// Disabled until every line is resolved, while a choice is being saved and while the delivery is received; a
    /// received invoice has nothing left to confirm.
    var canConfirm: Bool { !isReceived && allResolved && savingLineIDs.isEmpty && !isConfirming }

    /// Confirm & receive: the lots and expiries still waiting are saved first, so the delivery comes in as typed; one
    /// that could not be saved stops it, with its toast, for another try.
    func confirm() async {
        guard canConfirm else { return }
        await confirmGuard.run {
            await flushPendingSaves()
            guard unsavedBatchIDs.isEmpty else { return }
            await receipt.receive(lines)
        }
    }

    func clearMessage() {
        message = nil
    }

    func clearGeneralError() {
        generalError = nil
    }

    // MARK: - Saving

    /// Saves one line's choice and shows the line the server answers. A refusal (the line already resolved, a product
    /// deleted, the invoice received or set aside meanwhile) shows as a toast and the invoice is read again; a failed
    /// connection leaves the line as it was for the admin to try again. Nothing changes on a received invoice, nor
    /// while it is being received.
    @discardableResult
    private func save(
        _ line: InvoiceLine, attempts: Int = 1,
        _ operation: (InvoiceLinesRepository) async throws -> InvoiceLine
    ) async -> InvoiceLine? {
        guard !isReceived, !isConfirming, !savingLineIDs.contains(line.id) else { return nil }
        savingLineIDs.insert(line.id)
        defer { savingLineIDs.remove(line.id) }
        var failure = AppError.unknown("Not saved")
        for attempt in 1...max(attempts, 1) {
            do {
                let answer = try await operation(repository)
                let saved = keepingUnsavedBatch(answer)
                replace(saved)
                return saved
            } catch {
                failure = AppError(error)
                if case .validation = failure { break }
                if attempt < attempts { try? await Task.sleep(for: .milliseconds(500)) }
            }
        }
        generalError = Self.shown(failure)
        if case .validation = failure { await reload() }
        return nil
    }

    /// A change to a line's lot or expiry (`InvoiceReviewViewModel+Batch.swift`), saved a moment after the last one;
    /// none once the delivery is received or while it is.
    func changeBatch(of id: UUID, _ change: (inout InvoiceLine) -> Void) {
        guard !isReceived, !isConfirming, let index = lines.firstIndex(where: { $0.id == id }) else { return }
        guard !isReadOnly else {
            refusedChanges += 1
            return
        }
        var line = lines[index]
        change(&line)
        guard line != lines[index] else { return }
        lines[index] = line
        unsavedBatchIDs.insert(id)
        batchSaves[id]?.cancel()
        // Kept alive by the task, so a lot typed just before leaving the screen is still saved.
        batchSaves[id] = Task { [saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            await self.saveBatch(of: id)
        }
    }

    /// Sends the line's lot (trimmed, none when empty) and expiry month. What was typed stays on screen whatever the
    /// answer: a failure shows as a toast and the next change, Return or leaving the screen tries again.
    func saveBatch(of id: UUID) async {
        batchSaves[id] = nil
        guard unsavedBatchIDs.contains(id), let line = lines.first(where: { $0.id == id }) else { return }
        let lot = line.lot?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        do {
            _ = try await repository.setBatch(of: id, lot: lot.isEmpty ? nil : lot, expiryMonth: line.expiryMonth)
            if let current = lines.first(where: { $0.id == id }),
               current.lot == line.lot, current.expiryMonth == line.expiryMonth {
                unsavedBatchIDs.remove(id)
            }
        } catch {
            let error = AppError(error)
            generalError = Self.shown(error)
            if case .validation = error { await reload() }
        }
    }

    /// Nothing here is queued offline (MS-108 queues stock changes), so a lost connection reads "Couldn't save. Try
    /// again." rather than the retry the queue promises.
    private static func shown(_ error: AppError) -> AppError {
        error == .network ? .unknown("No connection") : error
    }

    private func replace(_ line: InvoiceLine) {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return }
        lines[index] = line
    }
}
