import Foundation

/// The demo clinic's billing as f34 draws it: three months free ending January 6, 2027, the lifetime promotion, a Visa
/// card and the owner's address. `-billingNoCard YES` starts it without a card; the trial may end on another day.
struct DemoBillingRepository: BillingRepository {
    let hasCard: Bool
    let trialEndsAt: Date

    init(hasCard: Bool = true, trialEndsAt: Date = BillingSummary.demoTrialEnd) {
        self.hasCard = hasCard
        self.trialEndsAt = trialEndsAt
    }

    func summary(clinicID: UUID) async throws -> BillingSummary {
        BillingSummary.demo(hasCard: hasCard, trialEndsAt: trialEndsAt)
    }
}

extension BillingSummary {
    /// f34: January 6, 2027 at 9 am in Toronto.
    nonisolated static let demoTrialEnd = Date(timeIntervalSince1970: 1_799_244_000)

    nonisolated static func demo(hasCard: Bool, trialEndsAt: Date = demoTrialEnd) -> BillingSummary {
        BillingSummary(
            trialEndsAt: trialEndsAt,
            subscriptionStatus: hasCard ? .active : .trialing,
            hasSubscription: hasCard,
            promoLifetime50: true,
            cardBrand: hasCard ? "visa" : nil,
            cardLast4: hasCard ? "4242" : nil,
            currentPeriodEnd: hasCard ? demoTrialEnd : nil,
            invoiceCount: 0,
            billingEmail: "owner@smiledental.ca",
            billingEmailCount: 1
        )
    }
}
