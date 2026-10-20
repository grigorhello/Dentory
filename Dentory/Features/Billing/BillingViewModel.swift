import Foundation
import Observation

/// Billing (f34, PRD §6.9 and §9, Admin only): the trial or plan card, the payment method with Add or Change, and the
/// invoice and billing email rows. Add opens Stripe Checkout and Change the Customer Portal in the in-app browser; when
/// it closes, Billing reloads until Stripe's webhook has changed what it shows (MS-140). The last answer is served
/// from the cache while a fresh one loads or the network is gone (MS-108).
@MainActor
@Observable
final class BillingViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// The Stripe page open in the in-app browser.
    struct PaymentPage: Identifiable, Equatable {
        let url: URL
        var id: URL { url }
    }

    private(set) var state: LoadState = .loading
    private(set) var summary: BillingSummary?
    var paymentPage: PaymentPage?
    private(set) var isOpeningPayment = false
    /// A toast the screen shows once.
    private(set) var message: String?
    let formatters: ClinicFormatters

    private let repository: BillingRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let pause: @Sendable (Duration) async -> Void

    /// How long Billing keeps checking for the webhook after the payment page closes: about half a minute.
    static let webhookChecks: [Duration] = [.zero, .seconds(2), .seconds(3), .seconds(5), .seconds(8), .seconds(12)]

    init(
        clinicID: UUID, repository: BillingRepository, cache: ResponseCaching, formatters: ClinicFormatters,
        pause: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.clinicID = clinicID
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.pause = pause
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

    /// Add or Change: Checkout without a subscription, the Customer Portal with one.
    func managePayment() async {
        guard let summary, !isOpeningPayment else { return }
        isOpeningPayment = true
        defer { isOpeningPayment = false }
        do {
            if let url = try await repository.paymentPage(clinicID: clinicID, hasSubscription: summary.hasSubscription) {
                paymentPage = PaymentPage(url: url)
            } else {
                await waitForStripe(since: summary)
            }
        } catch {
            message = AppError(error).userMessage
        }
    }

    /// The in-app browser closed: reload until the webhook has changed the card or the plan, for about half a minute.
    /// Nothing tells whether the admin paid or cancelled, so a cancelled page ends the checks quietly.
    func paymentPageClosed() async {
        paymentPage = nil
        guard let before = summary else { return }
        await waitForStripe(since: before)
    }

    func clearMessage() {
        message = nil
    }

    private func waitForStripe(since before: BillingSummary) async {
        for delay in Self.webhookChecks {
            if delay > .zero { await pause(delay) }
            guard !Task.isCancelled else { return }
            await load()
            if summary?.paymentState != before.paymentState { return }
        }
    }
}
