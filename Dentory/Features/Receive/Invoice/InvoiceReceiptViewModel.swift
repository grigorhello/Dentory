import Foundation
import Observation

/// Confirm & receive (f23 `invoice.confirm`; PRD §6.5 Confirm; MS-131): the reviewed lines go into stock as one server
/// action, `invoice_confirm`, which converts packs to counted units, keeps the cost per counted unit, fills the
/// batches with the lots and expiries, moves the products' To buy lines to Received and learns the supplier's words.
/// The screen then opens Inventory with "Delivery received · Inventory increased for N products." and Undo while the
/// server's action is known (a confirmation queued offline has none yet, MS-100 D10); Undo puts the delivery back and
/// the invoice waits for review again. Sends `invoice.confirm` (MS-147). Review invoice runs it once its lots and
/// expiries are saved, one confirmation at a time.
@MainActor
@Observable
final class InvoiceReceiptViewModel {
    /// The toast Inventory shows once the delivery is in; Undo is offered while `actionID` is known.
    struct Received: Equatable {
        let title: String
        let detail: String
        let actionID: UUID?
    }

    static let receivedTitle = "Delivery received"

    /// Set once the delivery is received, or queued offline: the screen opens Inventory with the toast.
    private(set) var received: Received?
    /// A refusal (the invoice received or changed on another device, a product deleted), shown as a toast.
    private(set) var generalError: AppError?

    private let invoiceID: UUID
    /// When the invoice was uploaded, where `duration_s` starts.
    private let uploadedAt: Date?
    private let repository: InvoiceReceivingRepository
    private let analytics: Analytics
    private let clock: Clock
    /// Reads the invoice again after a refusal: what the server has now shows (a received invoice, read-only).
    private let reload: @MainActor () async -> Void

    init(
        invoice: InvoiceSummary, repository: InvoiceReceivingRepository, analytics: Analytics, clock: Clock,
        reload: @escaping @MainActor () async -> Void
    ) {
        invoiceID = invoice.id
        uploadedAt = invoice.createdAt
        self.repository = repository
        self.analytics = analytics
        self.clock = clock
        self.reload = reload
    }

    /// Receives the delivery as `lines` stand on the server: the products they increase make the toast's count.
    func receive(_ lines: [InvoiceLine]) async {
        generalError = nil
        do {
            let outcome = try await repository.confirm(invoiceID: invoiceID)
            analytics.track(event(for: lines))
            let actionID: UUID? = if case .applied(let id) = outcome { id } else { nil }
            received = Received(
                title: Self.receivedTitle, detail: Self.receivedDetail(products: Self.products(in: lines)),
                actionID: actionID
            )
        } catch {
            let error = AppError(error)
            generalError = error
            if case .validation = error { await reload() }
        }
    }

    /// The toast's Undo, which runs after the screen has gone: the delivery goes back and the invoice waits for review
    /// again. Answers what went wrong, for a toast of its own.
    func undo(_ actionID: UUID) async -> AppError? {
        do {
            try await repository.undoConfirm(actionID: actionID)
            return nil
        } catch {
            return AppError(error)
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    /// "Inventory increased for 3 products.", one product in the singular; a delivery of fees only adds nothing.
    static func receivedDetail(products: Int) -> String {
        switch products {
        case 0: "Nothing was added to inventory."
        case 1: "Inventory increased for 1 product."
        default: "Inventory increased for \(products) products."
        }
    }

    /// The products the delivery increases: a product on two lines counts once.
    static func products(in lines: [InvoiceLine]) -> Int {
        Set(lines.filter(\.receivesStock).compactMap(\.productID)).count
    }

    /// The invoice's lines, those matched when it was read, the products created for it, and the seconds since its
    /// upload: counts only, never the supplier or a line's words.
    private func event(for lines: [InvoiceLine]) -> AnalyticsEvent {
        let seconds = uploadedAt.map { max(Int(clock.now.timeIntervalSince($0).rounded()), 0) } ?? 0
        return .invoiceConfirmed(
            lines: lines.count, matched: lines.filter { $0.readState == .matched }.count,
            created: lines.filter { $0.state == .created }.count, seconds: seconds
        )
    }
}
