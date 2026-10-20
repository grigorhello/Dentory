import Foundation
import Observation

/// A past procedure (f14; PRD §6.3 From history; Appendix B `procDetail` in modes done and editing; Appendix C
/// `cancelProcedure`): the record with Edit usage and Cancel procedure; editing with steppers, the X, Add item and
/// Take new, saved as the difference; and a cancelled procedure, read-only. The usage being edited is a
/// `ProcedureUsageDraft`; the lines are in `ProcedureEventViewModel+Lines.swift`.
@MainActor
@Observable
final class ProcedureEventViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    enum Mode: Equatable { case done, editing }

    typealias Supply = ProcedureUsageDraft.Supply
    typealias Bottle = ProcedureUsageDraft.Bottle

    enum Sheet: Identifiable, Equatable {
        case addItem, cancel
        var id: Self { self }
    }

    /// A toast the screen shows.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }

    private(set) var state: LoadState = .loading
    private(set) var detail: ProcedureEventDetail?
    private(set) var mode: Mode = .done
    /// The usage being edited; the record's own while not editing.
    private(set) var draft = ProcedureUsageDraft()
    /// The clinic's products for Add item, loaded when the sheet opens.
    private(set) var products: [ProductSummary] = []
    private(set) var hasLoadedProducts = false
    /// The products did not load: Add item says so in place of its list.
    private(set) var productsFailed = false
    /// The multi-use product Add item could not take new: its row reads "Out of stock" while the sheet is open.
    private(set) var outOfStockProductID: UUID?
    var searchText = ""
    var sheet: Sheet?
    var cancelNote = ""
    /// Why Cancel procedure failed, shown in the sheet: a toast would sit behind it.
    private(set) var cancelError: String?
    /// Set once the procedure is cancelled: the screen shows it as a toast and goes back.
    private(set) var finished: Message?
    private(set) var message: Message?
    private(set) var generalError: AppError?

    let formatters: ClinicFormatters
    private let repository: ProcedureEventRepository
    private let clinicID: UUID
    private let eventID: UUID
    /// Home's Edit usage opens the procedure straight in editing mode.
    private var startsEditing: Bool
    private let analytics: Analytics
    private let submitGuard = SubmitGuard()

    init(
        repository: ProcedureEventRepository, formatters: ClinicFormatters, clinicID: UUID, eventID: UUID,
        startsEditing: Bool = false, analytics: Analytics
    ) {
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
        self.eventID = eventID
        self.startsEditing = startsEditing
        self.analytics = analytics
    }

    var isSubmitting: Bool { submitGuard.isBusy }
    var supplies: [Supply] { draft.supplies }
    var bottles: [Bottle] { draft.bottles }

    /// Reads the record. An edit in progress is kept, and a reload that fails keeps the record on screen.
    func load() async {
        do {
            let detail = try await repository.event(id: eventID)
            self.detail = detail
            if mode == .done { draft = ProcedureUsageDraft(recording: detail.items) }
            state = .loaded
            if startsEditing {
                startsEditing = false
                startEditing()
            }
        } catch {
            if detail == nil { state = .failed(AppError(error)) }
        }
    }

    // MARK: - Modes

    func startEditing() {
        guard let detail, !detail.isCancelled else { return }
        draft = ProcedureUsageDraft(recording: detail.items)
        mode = .editing
    }

    /// Back to the record, nothing changed.
    func discard() {
        if let detail { draft = ProcedureUsageDraft(recording: detail.items) }
        mode = .done
    }

    // MARK: - Supplies

    /// The stepper's binding: `$viewModel[quantityOf: id]`, never below 0.
    subscript(quantityOf id: UUID) -> Int {
        get { draft[quantityOf: id] }
        set { draft[quantityOf: id] = newValue }
    }

    func remove(_ id: UUID) {
        draft.remove(id)
    }

    // MARK: - Add item

    func openAddItem() {
        searchText = ""
        outOfStockProductID = nil
        sheet = .addItem
    }

    func loadProducts() async {
        do {
            products = try await repository.products(clinicID: clinicID)
            hasLoadedProducts = true
            productsFailed = false
        } catch {
            productsFailed = true
        }
    }

    /// The products not on the procedure, countable and multi-use, matching the search, by name.
    var addableProducts: [ProductSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return products
            .filter { !draft.contains($0.id) }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A multi-use product with nothing unopened stays out and reads "Out of stock" on its row.
    func add(_ product: ProductSummary) {
        guard draft.add(product) else {
            outOfStockProductID = product.id
            return
        }
        sheet = nil
    }

    // MARK: - Take new

    /// Nothing unopened to take a new bottle from: a toast.
    func toggleTakeNew(_ id: UUID) {
        guard draft.toggleTakeNew(id) == .outOfStock, let bottle = bottles.first(where: { $0.id == id }) else {
            return
        }
        message = Message(title: "Out of stock", detail: bottle.item.name)
    }

    /// The (i) beside "Opened a new one?".
    func explainTakeNew() {
        message = Message(
            title: "Opened a new one?",
            detail: "Tap Take new when you open a fresh bottle, syringe or kit from stock. "
                + "Using an already open one changes nothing."
        )
    }

    // MARK: - Save

    var hasChanges: Bool { draft.hasChanges }

    var canSave: Bool { mode == .editing && hasChanges && !isSubmitting }

    /// Writes the difference (`stock_procedure_edit`), then shows the record with "Usage updated". Offline the edit
    /// is queued and the record shows it already.
    func save() async {
        guard canSave, let detail else { return }
        await submitGuard.run {
            generalError = nil
            let changes = draft.changeCount
            do {
                let outcome = try await repository.editUsage(draft.edit(eventID: eventID))
                analytics.track(.procedureUsageEdited(items: changes))
                message = Message(title: "Usage updated", detail: nil)
                self.detail = detail.with(items: draft.recordedItems)
                mode = .done
                if case .applied = outcome { await load() }
            } catch {
                generalError = AppError(error)
            }
        }
    }

    // MARK: - Cancel

    func askToCancel() {
        cancelNote = ""
        cancelError = nil
        sheet = .cancel
    }

    func keep() {
        sheet = nil
    }

    var canConfirmCancel: Bool {
        !cancelNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    /// Returns every countable to its batch and reverses the bottles still open (`stock_procedure_cancel`); the
    /// screen then goes back with "{name} cancelled · N items returned". A refusal keeps the sheet and the note.
    func cancelProcedure() async {
        guard canConfirmCancel, let detail else { return }
        await submitGuard.run {
            cancelError = nil
            let note = cancelNote.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                _ = try await repository.cancel(eventID: eventID, note: note)
                analytics.track(.procedureCancelled)
                sheet = nil
                finished = Message(title: "\(detail.name) cancelled", detail: Self.itemsReturned(detail.itemsDeducted))
            } catch {
                cancelError = AppError(error).userMessage
            }
        }
    }

    func clearMessage() {
        message = nil
    }

    func clearGeneralError() {
        generalError = nil
    }
}
