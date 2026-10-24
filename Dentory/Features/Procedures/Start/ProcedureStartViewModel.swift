import Foundation
import Observation

/// Adjust, then start (f13, f37): the template's countable supplies with steppers and remove, Add item, the
/// multi-use products with Take new, and Start procedure, which deducts every row, opens the bottles taken new
/// and records the procedure (`stock_procedure_start`). Nothing is blocked: a short item goes negative. The
/// summary, the row lines and the labels are in `ProcedureStartViewModel+Lines.swift`.
@MainActor
@Observable
final class ProcedureStartViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A countable supply on the list and the quantity this procedure takes; an added product defaults to 1.
    struct Supply: Identifiable, Equatable {
        let item: ProcedureTemplateItem
        var quantity: Int
        let defaultQuantity: Int
        var id: UUID { item.id }
    }

    /// A multi-use product: one of the template's, whose open one is used or a new one taken from stock, or one
    /// Add item brought in, which is always taken new.
    struct Bottle: Identifiable, Equatable {
        let item: ProcedureTemplateItem
        var takesNew = false
        /// Not in the template: Add item put it here taken new, and turning Take new off removes it.
        var isAdded = false
        var id: UUID { item.id }
    }

    /// A toast the screen shows: "Out of stock" for Take new, the (i) explanation, or the start.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }

    enum Sheet: Identifiable, Equatable {
        case addItem
        var id: Self { self }
    }

    private(set) var state: LoadState = .loading
    private(set) var name = ""
    private(set) var supplies: [Supply] = []
    private(set) var bottles: [Bottle] = []
    /// The clinic's products for Add item, loaded when the sheet opens.
    private(set) var products: [ProductSummary] = []
    private(set) var hasLoadedProducts = false
    /// The products did not load: Add item says so in place of its list (a toast would sit behind the sheet).
    private(set) var productsFailed = false
    /// The multi-use product Add item could not take new: its row reads "Out of stock" while the sheet is open.
    private(set) var outOfStockProductID: UUID?
    var sheet: Sheet?
    var searchText = ""
    /// Set once the procedure started: the screen shows it as a toast and goes back to Procedures.
    private(set) var started: Message?
    private(set) var message: Message?
    private(set) var generalError: AppError?

    private let repository: ProcedureStartRepository
    let formatters: ClinicFormatters
    private let clinicID: UUID
    private let templateID: UUID
    private let analytics: Analytics
    private let submitGuard = SubmitGuard()
    /// When the template came in; Start reports the seconds since (MS-147).
    private var loadedAt: Date?

    init(
        repository: ProcedureStartRepository, formatters: ClinicFormatters, clinicID: UUID, templateID: UUID,
        analytics: Analytics
    ) {
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
        self.templateID = templateID
        self.analytics = analytics
    }

    var isStarting: Bool { submitGuard.isBusy }

    func load() async {
        do {
            let detail = try await repository.template(id: templateID)
            name = detail.name
            supplies = detail.items.filter { $0.tracking == .countable }.map { item in
                let quantity = Self.wholeNumber(item.defaultQty)
                return Supply(item: item, quantity: quantity, defaultQuantity: quantity)
            }
            bottles = detail.items.filter { $0.tracking == .multiUse }.map { Bottle(item: $0) }
            state = .loaded
            loadedAt = loadedAt ?? formatters.clock.now
        } catch {
            state = .failed(AppError(error))
        }
    }

    // MARK: - Supplies

    /// The stepper's binding: `$viewModel[quantityOf: id]`, never below 0.
    subscript(quantityOf id: UUID) -> Int {
        get { supplies.first { $0.id == id }?.quantity ?? 0 }
        set {
            guard let index = supplies.firstIndex(where: { $0.id == id }) else { return }
            supplies[index].quantity = max(newValue, 0)
        }
    }

    /// The X of a row: the supply leaves this procedure (the template is not changed).
    func remove(_ id: UUID) {
        supplies.removeAll { $0.id == id }
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

    /// The products not on this procedure yet, countable and multi-use, matching the search, by name.
    var addableProducts: [ProductSummary] {
        let listed = Set(supplies.map(\.id) + bottles.map(\.id))
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return products
            .filter { !listed.contains($0.id) }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A countable product joins the supplies with quantity 1; a multi-use one is taken new for this procedure
    /// (one unopened opened under the user, reversed if the procedure is cancelled). With none unopened its row in
    /// the sheet reads "Out of stock" and nothing is added. The sheet closes once something was added.
    func add(_ product: ProductSummary) {
        guard !supplies.contains(where: { $0.id == product.id }), !bottles.contains(where: { $0.id == product.id })
        else { return }
        let item = ProcedureTemplateItem(
            id: product.id, name: product.name, unit: product.unit, tracking: product.tracking,
            defaultQty: product.tracking == .multiUse ? 0 : 1,
            quantity: product.quantity, unopened: product.unopened, openCount: product.openCount
        )
        switch product.tracking {
        case .countable:
            supplies.append(Supply(item: item, quantity: 1, defaultQuantity: 1))
        case .multiUse:
            guard product.unopened > 0 else {
                outOfStockProductID = product.id
                return
            }
            bottles.append(Bottle(item: item, takesNew: true, isAdded: true))
        }
        sheet = nil
    }

    // MARK: - Take new

    /// On: one unopened bottle is taken into use and counts as an item; again: off, and a product Add item brought
    /// in leaves the procedure. Nothing unopened: a toast.
    func toggleTakeNew(_ id: UUID) {
        guard let index = bottles.firstIndex(where: { $0.id == id }) else { return }
        if bottles[index].isAdded && bottles[index].takesNew {
            bottles.remove(at: index)
            return
        }
        if !bottles[index].takesNew && bottles[index].item.unopened <= 0 {
            message = Message(title: "Out of stock", detail: bottles[index].item.name)
            return
        }
        bottles[index].takesNew.toggle()
    }

    /// The (i) beside "Opened a new one?".
    func explainTakeNew() {
        message = Message(
            title: "Opened a new one?",
            detail: "Tap Take new when you open a fresh bottle, syringe or kit from stock. "
                + "Using an already open one changes nothing."
        )
    }

    // MARK: - Start

    /// Deducts every supply, opens the bottles taken new and records the procedure; the screen then goes back to
    /// Procedures with the toast. A refusal stays on the screen as a toast.
    func start() async {
        guard canStart else { return }
        await submitGuard.run {
            generalError = nil
            let count = itemCount
            let event = AnalyticsEvent.procedureStarted(
                items: count, bottlesOpened: bottles.count(where: \.takesNew), shortages: notAvailableCount,
                seconds: secondsSinceLoad
            )
            let request = ProcedureStartRequest(
                clinicID: clinicID,
                templateID: templateID,
                name: name,
                lines: supplies.map { ProcedureStartLine(productID: $0.id, quantity: Decimal($0.quantity)) }
                    + bottles.map { ProcedureStartLine(productID: $0.id, quantity: 0) },
                takeNew: bottles.filter(\.takesNew).map(\.id)
            )
            do {
                _ = try await repository.start(request)
                started = Message(title: "\(name) started", detail: Self.itemsDeducted(count))
                analytics.track(event)
            } catch {
                generalError = AppError(error)
            }
        }
    }

    func clearMessage() {
        message = nil
    }

    /// From the template's arrival to now, in whole seconds.
    private var secondsSinceLoad: Int {
        guard let loadedAt else { return 0 }
        return max(Int(formatters.clock.now.timeIntervalSince(loadedAt).rounded()), 0)
    }

    func clearGeneralError() {
        generalError = nil
    }

    private static func wholeNumber(_ value: Decimal) -> Int {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return max(NSDecimalNumber(decimal: rounded).intValue, 0)
    }
}
