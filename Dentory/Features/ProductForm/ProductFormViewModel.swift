import Foundation
import Observation

/// The New / Edit product sheet (PRD §6.4, Appendix C `newProduct`): the fields an admin types, the live
/// pack conversion sentence, the rules the sheet checks before saving (name and unit required, pack size
/// 2 or more, target at least the minimum, no tracking change while stock is held) and the save itself.
@MainActor
@Observable
final class ProductFormViewModel {
    enum Mode: Equatable {
        case create
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
    var minimumText: String { didSet { if minimumText != oldValue { targetError = nil } } }
    var targetText: String { didSet { if targetText != oldValue { targetError = nil } } }
    var supplier: String
    var location: String

    private(set) var nameError: String?
    private(set) var categoryError: String?
    private(set) var unitError: String?
    private(set) var packSizeError: String?
    private(set) var trackingError: String?
    private(set) var targetError: String?

    private let repository: ProductFormRepository
    private let formatters: ClinicFormatters
    private let clinicID: UUID
    private let submitGuard = SubmitGuard()

    init(repository: ProductFormRepository, formatters: ClinicFormatters, clinicID: UUID, mode: Mode) {
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
        self.mode = mode
        switch mode {
        case .create:
            name = ""
            unit = ""
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
            packSizeText = product.packSize.map(String.init) ?? ""
            isMultiUse = product.tracking == .multiUse
            minimumText = formatters.number(product.minimum)
            targetText = formatters.number(product.target)
            supplier = product.supplier ?? ""
            location = product.location ?? ""
        }
    }

    var isSubmitting: Bool { submitGuard.isBusy }
    var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    var title: String { isEditing ? "Edit product" : "New product" }
    var submitTitle: String { isEditing ? "Save changes" : "Create product" }
    /// Create, Save changes: the ticket's "Disabled until a name and unit are entered".
    var canSubmit: Bool { !trimmed(name).isEmpty && !trimmed(unit).isEmpty && !isSubmitting }
    /// "Quantity, expiry and lot are entered on the receiving form." shows on a new product only.
    var showsReceivingHint: Bool { !isEditing }

    var categoryChoices: [CategoryChoice] { categories.map(CategoryChoice.existing) + [.new] }
    var isNamingNewCategory: Bool { category == .new }

    func categoryTitle(_ choice: CategoryChoice) -> String {
        switch choice {
        case .existing(let category): category.name
        case .new: "New category…"
        }
    }

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
        return "Receive in \(Self.plural(of: pack)), count and use in \(countedUnitWord). "
            + "1 \(pack) adds \(size) \(countedUnitWord)."
    }

    var packSize: Int? { Int(trimmed(packSizeText)) }
    var trackingCaption: String { "Tracked as unopened and open items." }

    /// The switch moves unless the product holds stock (G1): then the inline error stays until it is 0.
    func setMultiUse(_ isOn: Bool) {
        guard isOn != isMultiUse else { return }
        if case .edit(let product) = mode, product.quantity > 0 {
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
                case .create:
                    outcome = .created(try await repository.createProduct(clinicID: clinicID, draft: draft))
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
        let minimum = Self.quantity(from: minimumText) ?? 0
        let target = Self.quantity(from: targetText) ?? 0
        if minimum < 0 || target < 0 { targetError = "Levels cannot be negative"; valid = false }
        if target < minimum { targetError = "Target must be at least the minimum"; valid = false }
        guard valid else { return nil }
        let categoryID: UUID? = if case .existing(let category) = category { category.id } else { nil }
        return ProductDraft(
            name: name,
            categoryID: categoryID,
            unit: unit,
            packUnit: pack.isEmpty ? nil : pack,
            packSize: pack.isEmpty ? nil : packSize,
            tracking: isMultiUse ? .multiUse : .countable,
            minimum: minimum,
            target: target,
            supplier: trimmed(supplier).isEmpty ? nil : trimmed(supplier),
            location: trimmed(location).isEmpty ? nil : trimmed(location)
        )
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

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "20", "20.5" or "20,5" as typed on the number pad.
    nonisolated static func quantity(from text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// "box" → "boxes", "bottle" → "bottles", "packs" stays: enough for the units a clinic types.
    nonisolated static func plural(of word: String) -> String {
        let lower = word.lowercased()
        if lower.hasSuffix("s") { return word }
        if ["x", "z", "ch", "sh"].contains(where: lower.hasSuffix) { return word + "es" }
        return word + "s"
    }
}
