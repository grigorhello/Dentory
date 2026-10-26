import Foundation
import Observation

/// Add expiry and Edit batch (PRD §4 Batch, §6.4 Expiry card, Appendix C `batch`), both roles: the month, how
/// many and the lot. Add expiry dates undated stock first and records anything beyond it as a Data correction;
/// Edit batch changes the month, the lot or the quantity, a changed quantity being a Data correction too
/// (`batch_upsert`, MS-106). Save waits for a month and a quantity, and on Edit batch for a change.
@MainActor
@Observable
final class BatchViewModel {
    enum Mode: Equatable {
        case add
        case edit(ProductBatch)
    }

    /// What the toast says after saving.
    struct Saved: Equatable {
        let title: String
        let detail: String
    }

    var expiryMonth: CalendarDay?
    var quantityText: String
    var lot: String
    private(set) var saved: Saved?
    /// A refusal the server gave; the sheet shows it above the button and keeps the input.
    private(set) var generalError: AppError?

    let mode: Mode
    let productName: String
    let unit: String
    /// Stock with no expiry date, which Add expiry dates first.
    let undated: Decimal
    private let productID: UUID
    private let repository: ProductDetailRepository
    private let formatters: ClinicFormatters
    private let submitGuard = SubmitGuard()

    init(detail: ProductDetail, mode: Mode, repository: ProductDetailRepository, formatters: ClinicFormatters) {
        let undated = max(detail.batches.filter { $0.expiryMonth == nil }.reduce(Decimal(0)) { $0 + $1.quantity }, 0)
        productID = detail.id
        productName = detail.name
        unit = detail.unit
        self.undated = undated
        self.mode = mode
        self.repository = repository
        self.formatters = formatters
        switch mode {
        case .add:
            expiryMonth = nil
            quantityText = undated > 0 ? QuantityText.plain(undated, locale: formatters.locale) : ""
            lot = ""
        case .edit(let batch):
            expiryMonth = batch.expiryMonth
            quantityText = QuantityText.plain(batch.quantity, locale: formatters.locale)
            lot = batch.lot ?? ""
        }
    }

    var isSubmitting: Bool { submitGuard.isBusy }
    var title: String { editedBatch == nil ? "Add expiry" : "Edit batch" }

    /// The month the wheels open on when none is chosen: this month in the clinic's time zone.
    var openingMonth: CalendarDay { formatters.thisMonth }

    /// Three years back (stock found already expired) to ten ahead, stretched to the batch's own year.
    var years: ClosedRange<Int> { formatters.expiryYears(including: expiryMonth) }

    func monthTitle(_ month: CalendarDay) -> String { formatters.shortMonth(month) }

    var quantity: Decimal? { QuantityText.parse(quantityText, locale: formatters.locale) }

    /// "Enter a number" once the field holds something that is not one.
    var quantityError: String? {
        let text = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && quantity == nil ? "Enter a number" : nil
    }

    /// Where the quantity comes from on Add expiry; what a changed quantity does on Edit batch.
    var quantityHint: String? {
        guard let quantity else { return nil }
        if let batch = editedBatch {
            let change = quantity - batch.quantity
            guard change != 0 else { return nil }
            let direction = change > 0 ? "more" : "fewer"
            return "\(number(abs(change))) \(direction) than before, recorded as a Data correction."
        }
        guard quantity > 0 else { return nil }
        if undated >= quantity { return "\(number(quantity)) \(unit) come from stock with no expiry date." }
        if undated > 0 {
            return "\(number(undated)) come from stock with no expiry date, "
                + "\(number(quantity - undated)) are added as a Data correction."
        }
        return "\(number(quantity)) \(unit) are added to stock as a Data correction."
    }

    var canSave: Bool {
        guard !isSubmitting, let expiryMonth, let quantity else { return false }
        guard let batch = editedBatch else { return quantity > 0 }
        let changed = expiryMonth != batch.expiryMonth || quantity != batch.quantity || trimmedLot != (batch.lot ?? "")
        return quantity >= 0 && changed
    }

    func save() async {
        guard canSave, let expiryMonth, let quantity else { return }
        await submitGuard.run {
            generalError = nil
            do {
                _ = try await repository.upsertBatch(
                    productID: productID, batchID: editedBatch?.id, expiryMonth: expiryMonth, quantity: quantity,
                    lot: trimmedLot.isEmpty ? nil : trimmedLot
                )
                saved = Saved(
                    title: "Expiry saved",
                    detail: "\(productName) · \(formatters.quantity(quantity, unit: unit)) · "
                        + formatters.shortMonth(expiryMonth)
                )
            } catch {
                generalError = AppError(error)
            }
        }
    }

    private var editedBatch: ProductBatch? {
        if case .edit(let batch) = mode { return batch }
        return nil
    }

    private var trimmedLot: String { lot.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func number(_ value: Decimal) -> String { formatters.number(value) }
}
