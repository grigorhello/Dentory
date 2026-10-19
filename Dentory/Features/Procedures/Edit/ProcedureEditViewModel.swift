import Foundation
import Observation

/// Edit procedure (f15, Appendix B `procEdit`), Admin only: the template's name, its default supplies (a countable
/// one with −/+ never under 1, a multi-use one with only the X), Add item, Save, and Delete procedure for a template
/// that exists. New procedure is the same screen without a template. Defaults change future procedures only; past
/// ones keep what they recorded. The copy is in `ProcedureEditViewModel+Copy.swift`.
@MainActor
@Observable
final class ProcedureEditViewModel: ProcedureItemPicking {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A supply on the template. A countable one carries its default quantity, at least 1; a multi-use one keeps 0 and
    /// is listed under "Opened a new one?" when the procedure starts.
    struct Item: Identifiable, Equatable {
        /// The product's id.
        let id: UUID
        let name: String
        let tracking: TrackingMode
        var quantity: Int
    }

    enum Sheet: Identifiable, Equatable {
        case addItem, delete
        var id: Self { self }
    }

    /// The toast Procedures shows once the template is saved or deleted; the screen then goes back.
    struct Outcome: Equatable {
        let title: String
        let detail: String?
    }

    static let untitledName = "Untitled procedure"
    static let nameLimit = 120

    let templateID: UUID?
    private(set) var state: LoadState
    var name = "" { didSet { if name != oldValue { nameError = nil } } }
    private(set) var nameError: String?
    private(set) var items: [Item] = []
    /// The name the template was loaded with: "Delete Root canal?" reads it, not the field being typed.
    private(set) var storedName = ""
    /// The clinic's products for Add item, loaded when the sheet opens.
    private(set) var products: [ProductSummary] = []
    private(set) var hasLoadedProducts = false
    var searchText = ""
    var sheet: Sheet?
    private(set) var outcome: Outcome?
    /// A refusal that belongs to no field; the screen shows it as a toast.
    private(set) var generalError: AppError?

    private let repository: ProcedureEditRepository
    private let clinicID: UUID
    private let saveGuard = SubmitGuard()
    private let deleteGuard = SubmitGuard()

    init(repository: ProcedureEditRepository, clinicID: UUID, templateID: UUID?) {
        self.repository = repository
        self.clinicID = clinicID
        self.templateID = templateID
        state = templateID == nil ? .loaded : .loading
    }

    var isNew: Bool { templateID == nil }
    var isSaving: Bool { saveGuard.isBusy }
    var isDeleting: Bool { deleteGuard.isBusy }
    var canSave: Bool { state == .loaded && !isSaving && !isDeleting }

    /// Opens the template once; a second call (the screen appearing again) keeps what the admin changed.
    func load() async {
        guard let templateID, state != .loaded else { return }
        do {
            let detail = try await repository.template(id: templateID)
            name = detail.name
            storedName = detail.name
            items = detail.items.map(Self.item(from:))
            state = .loaded
        } catch {
            state = .failed(AppError(error))
        }
    }

    // MARK: - Supplies

    /// The stepper's binding: `$viewModel[quantityOf: id]`, never below 1; a multi-use supply has no stepper.
    subscript(quantityOf id: UUID) -> Int {
        get { items.first { $0.id == id }?.quantity ?? 1 }
        set {
            guard let index = items.firstIndex(where: { $0.id == id }), items[index].tracking == .countable else {
                return
            }
            items[index].quantity = max(newValue, 1)
        }
    }

    /// The X of a row: the supply leaves the template when it is saved.
    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    // MARK: - Add item

    func openAddItem() {
        searchText = ""
        sheet = .addItem
    }

    func loadProducts() async {
        do {
            products = try await repository.products(clinicID: clinicID)
            hasLoadedProducts = true
        } catch {
            generalError = AppError(error)
        }
    }

    /// Every product not on the template yet, countable and multi-use, matching the search, by name.
    var addableProducts: [ProductSummary] {
        let listed = Set(items.map(\.id))
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return products
            .filter { !listed.contains($0.id) }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Appends the product, a countable one with 1 and a multi-use one with 0, and closes the sheet.
    func add(_ product: ProductSummary) {
        guard !items.contains(where: { $0.id == product.id }) else { return }
        let quantity = product.tracking == .countable ? 1 : 0
        items.append(Item(id: product.id, name: product.name, tracking: product.tracking, quantity: quantity))
        sheet = nil
    }

    // MARK: - Save and delete

    /// Sends the name and the supplies in screen order; the server stores an empty name as "Untitled procedure". A
    /// refused name shows under the field, any other refusal as a toast, and the screen keeps what was typed.
    func save() async {
        guard canSave else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= Self.nameLimit else {
            nameError = Self.nameTooLong
            return
        }
        await saveGuard.run {
            generalError = nil
            let request = ProcedureTemplateSaveRequest(
                clinicID: clinicID, templateID: templateID, name: trimmed,
                lines: items.map { .init(productID: $0.id, defaultQuantity: $0.tracking == .countable ? $0.quantity : 0) }
            )
            do {
                let saved = try await repository.save(request)
                outcome = Outcome(title: "Procedure saved", detail: Self.savedDetail(saved))
            } catch {
                handle(AppError(error))
            }
        }
    }

    func askToDelete() {
        sheet = .delete
    }

    func keep() {
        sheet = nil
    }

    /// Archives the template: it leaves Procedures, and the procedures performed from it keep their data.
    func delete() async {
        guard let templateID, !isSaving else { return }
        await deleteGuard.run {
            generalError = nil
            do {
                try await repository.archive(templateID: templateID)
                outcome = Outcome(title: "Procedure deleted", detail: storedName)
            } catch {
                handle(AppError(error))
            }
            sheet = nil
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    /// The server names the field it refuses (`hint = 'name'`). Saving is not queued, so no connection reads as a
    /// failed save (PRD §7), not as a change to be retried.
    private func handle(_ error: AppError) {
        switch error {
        case .validation(field: "name", let message):
            nameError = message
        case .network:
            generalError = .unknown("No connection")
        default:
            generalError = error
        }
    }

    private static func item(from item: ProcedureTemplateItem) -> Item {
        let quantity = item.tracking == .countable ? max(wholeNumber(item.defaultQty), 1) : 0
        return Item(id: item.id, name: item.name, tracking: item.tracking, quantity: quantity)
    }

    private static func wholeNumber(_ value: Decimal) -> Int {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
