import Foundation
import Observation

/// The Mark disposed sheet (Appendix C `dispose`, Admin): how much of the batch to dispose, the whole batch by
/// default and never more, and one submission at a time. It goes through `stock_dispose` with the reason Expired;
/// the result carries the action id the toast's Undo needs.
@MainActor
@Observable
final class DisposeBatchViewModel {
    /// What was disposed: the batch and quantity for the toast, the action id for Undo (nil while queued offline).
    struct Disposed: Equatable {
        let batch: ExpiringBatch
        let quantity: Decimal
        let actionID: UUID?
    }

    var quantityText: String
    private(set) var disposed: Disposed?
    /// A refusal the server gave; the sheet shows it above the button and keeps the input.
    private(set) var generalError: AppError?

    let batch: ExpiringBatch
    private let repository: ExpiringRepository
    private let formatters: ClinicFormatters
    private let submitGuard = SubmitGuard()

    init(batch: ExpiringBatch, repository: ExpiringRepository, formatters: ClinicFormatters) {
        self.batch = batch
        self.repository = repository
        self.formatters = formatters
        quantityText = formatters.number(batch.quantity)
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    /// "Bonding agent · lot BA7. Removed with reason Expired."
    var caption: String {
        let name = batch.lot.map { "\(batch.name) · lot \($0)" } ?? batch.name
        return "\(name). Removed with reason Expired."
    }

    /// The typed quantity, or nil when it is not a number.
    var quantity: Decimal? {
        let text = quantityText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let value = Decimal(string: text, locale: formatters.locale) else { return nil }
        return value
    }

    /// Under the field: more than the batch holds, or nothing to dispose.
    var quantityError: String? {
        guard let quantity else { return nil }
        if quantity > batch.quantity {
            return "At most \(formatters.quantity(batch.quantity, unit: batch.unit))."
        }
        return quantity <= 0 ? "Enter a quantity above 0." : nil
    }

    var canDispose: Bool {
        guard let quantity, quantity > 0, quantity <= batch.quantity else { return false }
        return !isSubmitting
    }

    func dispose() async {
        guard canDispose, let quantity else { return }
        await submitGuard.run {
            generalError = nil
            do {
                let outcome = try await repository.dispose(batchID: batch.id, quantity: quantity)
                let actionID: UUID? = if case .applied(let id) = outcome { id } else { nil }
                disposed = Disposed(batch: batch, quantity: quantity, actionID: actionID)
            } catch {
                generalError = AppError(error)
            }
        }
    }
}
