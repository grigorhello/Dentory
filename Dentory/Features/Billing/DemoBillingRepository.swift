import Foundation

/// The demo clinic's billing as f34 draws it: three months free ending January 6, 2027, the lifetime promotion, a Visa
/// card and the owner's address. `-billingNoCard YES` starts it without a card.
struct DemoBillingRepository: BillingRepository {
    let hasCard: Bool

    init(hasCard: Bool = true) {
        self.hasCard = hasCard
    }

    func summary(clinicID: UUID) async throws -> BillingSummary {
        BillingSummary.demo(hasCard: hasCard)
    }
}

extension BillingSummary {
    /// f34: January 6, 2027 at 9 am in Toronto.
    nonisolated static let demoTrialEnd = Date(timeIntervalSince1970: 1_799_244_000)

    nonisolated static func demo(hasCard: Bool) -> BillingSummary {
        BillingSummary(
            trialEndsAt: demoTrialEnd,
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
