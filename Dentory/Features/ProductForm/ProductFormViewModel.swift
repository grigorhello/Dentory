import Foundation
import Observation

/// The New / Edit product sheet (PRD §6.4, Appendix C `newProduct`): the fields an admin types, the live
/// pack conversion sentence, the rules the sheet checks before saving (name and unit required, pack size
/// 2 or more, target at least the minimum, no tracking change while stock is held) and the save itself. The titles
/// and fixed lines are in `ProductFormViewModel+Copy.swift`.
@MainActor
@Observable
final class ProductFormViewModel {
    enum Mode: Equatable {
        case create
        /// New on Choose product (Receive manually, MS-127): the name starts as what was searched for, and the button
        /// creates the product and chooses it on the receiving form.
        case createAndSelect(name: String)
        /// Add new or No, create new on an invoice line (Review invoice, MS-130): the notice quotes the line, the name
        /// and the counted-in unit start as the line suggests them, and the button creates the product and uses it for
        /// the line.
        case invoiceLine(raw: String, name: String, unit: String)
        case edit(ProductDetail)
    }

    /// The category picker's choices: the clinic's categories, then "New category…".
    nonisolated enum CategoryChoice: Hashable, Sendable {
        case existing(ProductCategory)
        case new
    }

    enum Outcome: Equatable {
        case created(UUID)
        case saved
    }

    let mode: Mode
    private(set) var categories: [ProductCategory] = []
    private(set) var outcome: Outcome?
    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?

    var name: String { didSet { if name != oldValue { nameError = nil } } }
    var category: CategoryChoice? { didSet { if category != oldValue { categoryError = nil } } }
    var newCategoryName = "" { didSet { if newCategoryName != oldValue { categoryError = nil } } }
    var unit: String { didSet { if unit != oldValue { unitError = nil } } }
    var packUnit: String { didSet { if packUnit != oldValue { packSizeError = nil } } }
    var packSizeText: String { didSet { if packSizeText != oldValue { packSizeError = nil } } }
    private(set) var isMultiUse: Bool
    var minimumText: String { didSet { if minimumText != oldValue { minimumError = nil; targetError = nil } } }
    var targetText: String { didSet { if targetText != oldValue { targetError = nil } } }
    var supplier: String
    var location: String

    private(set) var nameError: String?
    private(set) var categoryError: String?
    private(set) var unitError: String?
    private(set) var packSizeError: String?
    private(set) var trackingError: String?
    private(set) var minimumError: String?
    private(set) var targetError: String?

    private let repository: ProductFormRepository
    private let formatters: ClinicFormatters
    private let clinicID: UUID
    private let analytics: Analytics
    private let submitGuard = SubmitGuard()

    init(
        repository: ProductFormRepository, formatters: ClinicFormatters, clinicID: UUID, mode: Mode,
        analytics: Analytics
    ) {
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
        self.mode = mode
        self.analytics = analytics
        switch mode {
        case .create, .createAndSelect, .invoiceLine:
            name = Self.startingName(in: mode)
            unit = Self.startingUnit(in: mode)
            packUnit = ""
            packSizeText = ""
            isMultiUse = false
            minimumText = ""
            targetText = ""
            supplier = ""
            location = ""
        case .edit(let product):
            name = product.name
            unit = product.unit
            packUnit = product.packUnit ?? ""
            packSizeText = product.packSize.map { QuantityText.plain(Decimal($0), locale: formatters.locale) } ?? ""
            isMultiUse = product.tracking == .multiUse
            minimumText = QuantityText.plain(product.minimum, locale: formatters.locale)
            targetText = QuantityText.plain(product.target, locale: formatters.locale)
            supplier = product.supplier ?? ""
            location = product.location ?? ""
        }
    }

    var isSubmitting: Bool { submitGuard.isBusy }
    var isEditing: Bool { if case .edit = mode { return true } else { return false } }

    /// Create, Save changes: the ticket's "Disabled until a name and unit are entered".
    var canSubmit: Bool { !trimmed(name).isEmpty && !trimmed(unit).isEmpty && !isSubmitting }
    /// "Quantity, expiry and lot are entered on the receiving form." shows on a new product only.
    var showsReceivingHint: Bool { !isEditing }

    var categoryChoices: [CategoryChoice] { categories.map(CategoryChoice.existing) + [.new] }
    var isNamingNewCategory: Bool { category == .new }

    // MARK: - Units

    /// "How many cartridges in 1 box?", asked once a received-as unit is typed.
    var packQuestion: String? {
        guard !trimmed(packUnit).isEmpty else { return nil }
        return "How many \(countedUnitWord) in 1 \(trimmed(packUnit))?"
    }

    /// "Receive in boxes, count and use in cartridges. 1 box adds 50 cartridges." as the fields change.
    var packSentence: String? {
        guard !trimmed(packUnit).isEmpty else { return nil }
        guard let size = packSize, size >= 2 else { return "Stock is counted in the smaller unit." }
        let pack = trimmed(packUnit)
        return "Receive in \(ClinicFormatters.plural(of: pack)), count and use in \(countedUnitWord). "
            + "1 \(pack) adds \(size) \(countedUnitWord)."
    }

    var packSize: Int? { QuantityText.count(packSizeText, locale: formatters.locale) }

    /// The switch moves unless the product holds stock (G1): then the inline error stays until it is 0.
    func setMultiUse(_ isOn: Bool) {
        guard isOn != isMultiUse else { return }
        // Any stock blocks it, negative (MS-100 D9) or in open bottles: a quantity of 0 can be -1 unopened + 1 open.
        if case .edit(let product) = mode, product.unopened != 0 || product.openCount > 0 {
            trackingError = "Set stock to 0 before changing how it is tracked."
            return
        }
        trackingError = nil
        isMultiUse = isOn
    }

    // MARK: - Save

    func load() async {
        do {
            categories = try await repository.categories(clinicID: clinicID)
            if case .edit(let product) = mode, category == nil,
               let current = categories.first(where: { $0.id == product.categoryID })
                ?? categories.first(where: { $0.name == product.categoryName }) {
                category = .existing(current)
            }
        } catch {
            generalError = AppError(error)
        }
    }

    func save() async {
        guard canSubmit, var draft = validatedDraft() else { return }
        await submitGuard.run {
            generalError = nil
            do {
                if category == .new {
                    let created = try await repository.findOrCreateCategory(
                        clinicID: clinicID, name: trimmed(newCategoryName)
                    )
                    draft.categoryID = created.id
                }
                switch mode {
                case .create, .createAndSelect, .invoiceLine:
                    let id = try await repository.createProduct(clinicID: clinicID, draft: draft)
                    analytics.track(.productCreated)
                    outcome = .created(id)
                case .edit(let product):
                    try await repository.updateProduct(id: product.id, draft: draft)
                    outcome = .saved
                }
            } catch {
                handle(AppError(error))
            }
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    /// The draft once every rule holds; otherwise the first failing field carries its error.
    private func validatedDraft() -> ProductDraft? {
        var valid = true
        let name = trimmed(name)
        let unit = trimmed(unit)
        let pack = trimmed(packUnit)
        if name.isEmpty { nameError = "Enter a name"; valid = false }
        if unit.isEmpty { unitError = "Enter the unit it is counted in"; valid = false }
        if category == .new, trimmed(newCategoryName).isEmpty { categoryError = "Enter a category name"; valid = false }
        if !pack.isEmpty, (packSize ?? 0) < 2 {
            packSizeError = "Enter how many \(countedUnitWord) make 1 \(pack), 2 or more"
            valid = false
        }
        guard let levels = validatedLevels(), valid else { return nil }
        // No choice on the Edit sheet (the list may not have loaded) keeps the product's category.
        let categoryID: UUID? = switch (category, mode) {
        case (.existing(let chosen), _): chosen.id
        case (nil, .edit(let product)): product.categoryID
        default: nil
        }
        return ProductDraft(
            name: name,
            categoryID: categoryID,
            unit: unit,
            packUnit: pack.isEmpty ? nil : pack,
            packSize: pack.isEmpty ? nil : packSize,
            tracking: isMultiUse ? .multiUse : .countable,
            minimum: levels.minimum,
            target: levels.target,
            supplier: trimmed(supplier).isEmpty ? nil : trimmed(supplier),
            location: trimmed(location).isEmpty ? nil : trimmed(location)
        )
    }

    /// Both levels as numbers (empty reads 0), the target at least the minimum; otherwise the failing field
    /// carries its error and nothing is sent.
    private func validatedLevels() -> (minimum: Decimal, target: Decimal)? {
        let minimum = QuantityText.parse(minimumText, locale: formatters.locale)
        let target = QuantityText.parse(targetText, locale: formatters.locale)
        if minimum == nil, !trimmed(minimumText).isEmpty { minimumError = "Enter a number" }
        if target == nil, !trimmed(targetText).isEmpty { targetError = "Enter a number" }
        guard minimumError == nil, targetError == nil else { return nil }
        let levels = (minimum: minimum ?? 0, target: target ?? 0)
        if levels.target < levels.minimum {
            targetError = "Target must be at least the minimum"
            return nil
        }
        return levels
    }

    private func handle(_ error: AppError) {
        switch error {
        case .validation(_, let message) where message.localizedCaseInsensitiveContains("tracked"):
            trackingError = message
        case .validation(_, let message) where message.localizedCaseInsensitiveContains("minimum"):
            targetError = message
        default:
            generalError = error
        }
    }

    private var countedUnitWord: String { trimmed(unit).isEmpty ? "units" : trimmed(unit) }

    /// What Choose product's search held when New was tapped, so the name is not typed twice, or the name an invoice
    /// line suggests.
    private static func startingName(in mode: Mode) -> String {
        switch mode {
        case .createAndSelect(let name), .invoiceLine(_, let name, _):
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        case .create, .edit:
            ""
        }
    }

    /// The counted-in unit an invoice line suggests ("packs").
    private static func startingUnit(in mode: Mode) -> String {
        guard case .invoiceLine(_, _, let unit) = mode else { return "" }
        return unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
