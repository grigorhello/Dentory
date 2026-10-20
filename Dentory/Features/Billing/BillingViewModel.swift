import Foundation
import Observation

/// Billing (f34, PRD §6.9 and §9, MS-100 D18, Admin only): the trial or plan card with its price, the payment method's
/// status, and the invoice and billing email rows. The app opens no Stripe page: the clinic adds or changes its card
/// from the links Dentory emails, and Billing shows the result once Stripe's webhook has written it, on the next
/// return to the app or pull to refresh. The last answer is served from the cache while a fresh one loads or the
/// network is gone (MS-108).
@MainActor
@Observable
final class BillingViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    private(set) var state: LoadState = .loading
    private(set) var summary: BillingSummary?
    let formatters: ClinicFormatters

    private let repository: BillingRepository
    private let cache: ResponseCaching
    private let clinicID: UUID

    init(clinicID: UUID, repository: BillingRepository, cache: ResponseCaching, formatters: ClinicFormatters) {
        self.clinicID = clinicID
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        summary = cache.load(BillingSummary.self, for: Self.cacheKey(clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "BillingRepository.summary", clinicID: clinicID)
    }

    func load() async {
        do {
            let fresh = try await repository.summary(clinicID: clinicID)
            summary = fresh
            cache.store(fresh, for: Self.cacheKey(clinicID))
            state = .loaded
        } catch {
            state = summary == nil ? .failed(AppError(error)) : .loaded
        }
    }
}
