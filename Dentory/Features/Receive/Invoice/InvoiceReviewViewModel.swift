import Foundation
import Observation

/// Review invoice once read (f23, f38; PRD §6.5 Review invoice; Appendix B `invoice.line[n]`, `invoice.summary`,
/// `invoice.confirm`; Appendix C `match`, `newProduct`), Admin only: each line with its state and the choice it waits
/// for. Yes, match, Ignore and a resolved line's badge (back to the state it was read in) are saved at once; Pick
/// existing and Pick product open Which product is this?; Add new and No, create new open New product; the lot and
/// expiry month of a Matched or Created line are saved a moment after the last change. Every choice is saved on the
/// server, so the admin can leave and come back. Confirm & receive waits for every line to be resolved; receiving is
/// MS-131's. The words are in `InvoiceReviewViewModel+Copy.swift`.
@MainActor
@Observable
final class InvoiceReviewViewModel {
    /// The sheet over the lines.
    enum Sheet: Identifiable, Equatable {
        /// Which product is this? (Appendix C `match`), from a New product's Pick existing or a fee's Pick product.
        case match(InvoiceLine)
        /// New product from the line (Appendix C `newProduct`), from Add new or No, create new.
        case newProduct(InvoiceLine)

        var id: String {
            switch self {
            case .match(let line): "match-\(line.id)"
            case .newProduct(let line): "newProduct-\(line.id)"
            }
        }
    }

    /// A choice a line waits for (Appendix B `invoice.line[n].a` and `.b`).
    enum Choice: Equatable {
        case yesMatch, createNew, addNew, pickExisting, ignore, pickProduct
    }

    /// A toast the screen shows.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }

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

    let invoiceID: UUID
    /// In the invoice's own currency.
    let formatters: ClinicFormatters
    private let repository: InvoiceLinesRepository
    private let saveDelay: Duration
    /// Reads the invoice again after a refusal: the line, or the whole invoice, may have changed meanwhile.
    private let reload: @MainActor () async -> Void
    /// Lines whose lot or expiry changed since it was last saved; a reload keeps them over the server's.
    private var unsavedBatchIDs: Set<UUID> = []
    private var batchSaves: [UUID: Task<Void, Never>] = [:]

    init(
        invoice: InvoiceSummary, repository: InvoiceLinesRepository, formatters: ClinicFormatters,
        saveDelay: Duration = .milliseconds(600), reload: @escaping @MainActor () async -> Void
    ) {
        invoiceID = invoice.id
        lines = invoice.lines
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
        guard line.canReopen else { return }
        await save(line) { try await $0.reopenLine(line.id) }
    }

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

    // MARK: - Lot and expiry

    /// The Lot input's binding, `$viewModel[lotOf: id]`: up to the 60 characters a lot keeps, saved a moment after the
    /// last change.
    subscript(lotOf id: UUID) -> String {
        get { lines.first { $0.id == id }?.lot ?? "" }
        set {
            let lot = String(newValue.prefix(Self.lotLength))
            changeBatch(of: id) { $0.lot = lot.isEmpty ? nil : lot }
        }
    }

    /// The Expiry input's binding, `$viewModel[expiryOf: id]`, kept as the month's first day.
    subscript(expiryOf id: UUID) -> YearMonth? {
        get { lines.first { $0.id == id }?.expiryMonth.map(YearMonth.init(day:)) }
        set { changeBatch(of: id) { $0.expiryMonth = newValue.map(CalendarDay.init(yearMonth:)) } }
    }

    /// Return on the Lot input saves it straight away.
    func saveBatchNow(of id: UUID) {
        guard unsavedBatchIDs.contains(id) else { return }
        batchSaves[id]?.cancel()
        batchSaves[id] = Task { await self.saveBatch(of: id) }
    }

    /// Saves every lot and expiry still waiting: on leaving the screen, and before Confirm & receive (MS-131).
    func flushPendingSaves() async {
        for id in unsavedBatchIDs {
            batchSaves[id]?.cancel()
            await saveBatch(of: id)
        }
    }

    /// Discard invoice: what was typed is not sent any more.
    func dropPendingSaves() {
        batchSaves.values.forEach { $0.cancel() }
        batchSaves = [:]
        unsavedBatchIDs = []
    }

    // MARK: - Confirm & receive

    /// Every line resolved: Matched, Created or Skipped.
    var allResolved: Bool { !lines.isEmpty && lines.allSatisfy(\.isResolved) }

    /// Disabled until every line is resolved, and while a choice is being saved.
    var canConfirm: Bool { allResolved && savingLineIDs.isEmpty }

    /// Receiving the delivery is MS-131's; until then the button says so.
    func confirm() {
        guard canConfirm else { return }
        message = Message(title: Self.confirmArrivesLater, detail: nil)
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
    /// connection leaves the line as it was for the admin to try again.
    @discardableResult
    private func save(
        _ line: InvoiceLine, attempts: Int = 1,
        _ operation: (InvoiceLinesRepository) async throws -> InvoiceLine
    ) async -> InvoiceLine? {
        guard !savingLineIDs.contains(line.id) else { return nil }
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

    private func changeBatch(of id: UUID, _ change: (inout InvoiceLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
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
    private func saveBatch(of id: UUID) async {
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

    /// A line from the server with the lot and expiry typed here, while they are not saved yet.
    private func keepingUnsavedBatch(_ fresh: InvoiceLine) -> InvoiceLine {
        guard unsavedBatchIDs.contains(fresh.id), let current = lines.first(where: { $0.id == fresh.id }) else {
            return fresh
        }
        var line = fresh
        line.lot = current.lot
        line.expiryMonth = current.expiryMonth
        return line
    }
}
