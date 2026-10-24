import Foundation
import Observation

/// The Adjust inventory sheet (PRD Appendix C `adjust`, both roles): the actual quantity against the
/// system estimate, a reason, a note when the reason is Other, and one submission at a time. Saving goes
/// through `stock_adjust`; the result carries the action id the toast's Undo needs.
@MainActor
@Observable
final class AdjustInventoryViewModel {
    /// What was saved: before and after for the toast, the action id for Undo (nil while queued offline).
    struct Saved: Equatable {
        let actionID: UUID?
        let before: Decimal
        let after: Decimal
        let reason: AdjustmentReason
    }

    var quantityText: String
    var reason: AdjustmentReason?
    var note = ""
    private(set) var saved: Saved?
    /// A refusal the server gave; the sheet shows it above the button and keeps the input.
    private(set) var generalError: AppError?

    let productName: String
    let unit: String
    /// The system estimate the quantity is compared with: unopened only for a multi-use product (MS-100 G3).
    let estimate: Decimal
    let isMultiUse: Bool
    private let productID: UUID
    private let repository: ProductDetailRepository
    private let formatters: ClinicFormatters
    private let submitGuard = SubmitGuard()

    init(detail: ProductDetail, repository: ProductDetailRepository, formatters: ClinicFormatters) {
        let estimate = detail.tracking == .multiUse ? detail.unopened : detail.quantity
        productID = detail.id
        productName = detail.name
        unit = detail.unit
        isMultiUse = detail.tracking == .multiUse
        self.estimate = estimate
        quantityText = formatters.editableNumber(estimate)
        self.repository = repository
        self.formatters = formatters
    }

    static let reasons = AdjustmentReason.allCases

    var isSubmitting: Bool { submitGuard.isBusy }

    /// "System estimate 54 cartridges. A reason is recorded in history."; a multi-use product counts unopened.
    var caption: String {
        let figure = isMultiUse
            ? "\(formatters.number(estimate)) unopened"
            : formatters.quantity(estimate, unit: unit)
        return "System estimate \(figure). A reason is recorded in history."
    }

    var quantityLabel: String { isMultiUse ? "Unopened" : "Actual quantity" }

    /// The typed quantity, or nil when it is not a number.
    var actualQuantity: Decimal? {
        formatters.parseNumber(quantityText)
    }

    var quantityError: String? {
        guard let actualQuantity else { return nil }
        return actualQuantity < 0 ? "A quantity cannot be negative." : nil
    }

    var needsNote: Bool { reason?.requiresNote ?? false }

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Save waits for a quantity that differs from the estimate, a reason, and a note when the reason is Other.
    var canSave: Bool {
        guard let actualQuantity, actualQuantity >= 0, actualQuantity != estimate, let reason else { return false }
        if reason.requiresNote && trimmedNote.isEmpty { return false }
        return !isSubmitting
    }

    func save() async {
        guard canSave, let actualQuantity, let reason else { return }
        await submitGuard.run {
            generalError = nil
            do {
                let outcome = try await repository.adjust(
                    productID: productID, actualQuantity: actualQuantity, reason: reason,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )
                let actionID: UUID? = if case .applied(let id) = outcome { id } else { nil }
                saved = Saved(actionID: actionID, before: estimate, after: actualQuantity, reason: reason)
            } catch {
                generalError = AppError(error)
            }
        }
    }
}
