import Foundation
import Observation

/// Invoices (f35, PRD §6.9, MS-141, Admin only): the clinic's Stripe invoices, newest first, each with its date, amount
/// and status, and no link (MS-100 D18: Stripe emails them). The last answer shows from the cache while a fresh one
/// loads or the network is gone (MS-108).
@MainActor
@Observable
final class InvoicesViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A row of f35.
    struct Row: Equatable, Identifiable {
        let id: UUID
        let date: String
        let number: String?
        let amount: String
        let status: String
        let tone: StatusTone
    }

    private(set) var state: LoadState = .loading
    private(set) var invoices: [BillingInvoice]?

    private let clinicID: UUID
    private let repository: BillingRepository
    private let cache: ResponseCaching
    private let formatters: ClinicFormatters
    private let trialEndsAt: Date?

    init(
        clinicID: UUID, repository: BillingRepository, cache: ResponseCaching, formatters: ClinicFormatters,
        trialEndsAt: Date?
    ) {
        self.clinicID = clinicID
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.trialEndsAt = trialEndsAt
        invoices = cache.load([BillingInvoice].self, for: Self.cacheKey(clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "BillingRepository.invoices", clinicID: clinicID)
    }

    func load() async {
        do {
            let fresh = try await repository.invoices(clinicID: clinicID)
            invoices = fresh
            cache.store(fresh, for: Self.cacheKey(clinicID))
            state = .loaded
        } catch {
            state = invoices == nil ? .failed(AppError(error)) : .loaded
        }
    }

    var rows: [Row] {
        (invoices ?? []).map { invoice in
            let status = Self.status(invoice)
            return Row(
                id: invoice.id, date: formatters.date(invoice.issuedAt), number: invoice.number,
                amount: Self.amount(cents: invoice.amountCents, currency: invoice.currency),
                status: status.text, tone: status.tone
            )
        }
    }

    /// f35's empty state, with when the first invoice comes.
    static let emptyTitle = "No invoices yet"

    var emptyCaption: String {
        guard let trialEndsAt, trialEndsAt > formatters.clock.now else {
            return "Each invoice appears here once it is issued, and its receipt goes to your billing emails."
        }
        return "Your first invoice is issued when the trial ends on \(formatters.longDate(trialEndsAt)). "
            + "Each one appears here, and its receipt goes to your billing emails."
    }

    /// Paid in success, Open in warning, Failed in danger (ticket MS-141): an open invoice Stripe could not charge, while
    /// it retries, or one it gave up on; a voided invoice is Void.
    nonisolated static func status(_ invoice: BillingInvoice) -> (text: String, tone: StatusTone) {
        switch invoice.status {
        case .paid: ("Paid", .success)
        case .open where invoice.paymentFailed: ("Failed", .danger)
        case .draft, .open: ("Open", .warning)
        case .uncollectible: ("Failed", .danger)
        case .void: ("Void", .neutral)
        }
    }

    /// "$49.50" in the invoice's own currency (US dollars, MS-140), whatever the clinic's.
    nonisolated static func amount(cents: Int, currency: String) -> String {
        (Decimal(cents) / 100).formatted(
            .currency(code: currency.uppercased()).precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))
        )
    }
}
