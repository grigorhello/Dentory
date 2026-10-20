import Foundation

/// Billing's words (f34, ticket MS-140, MS-100 D18): the trial or plan card, the USD price list, the payment method's
/// status and the rows. Nothing here sends the admin to a payment page; the links come by email.
extension BillingViewModel {
    /// The dark card: the trial while it runs (a card on file or not), then the plan, or what ended without one.
    enum CardKind: Equatable {
        case trial, trialEnded, subscriptionEnded, plan
    }

    var cardKind: CardKind {
        guard let summary, summary.trialEndsAt <= formatters.clock.now else { return .trial }
        if summary.hasSubscription { return .plan }
        return summary.subscriptionStatus == .canceled ? .subscriptionEnded : .trialEnded
    }

    /// "Free trial" until a trial ends without a card, "Plan" once one was paid; the eyebrow uppercases it.
    var eyebrow: String {
        switch cardKind {
        case .trial, .trialEnded: "Free trial"
        case .plan, .subscriptionEnded: "Plan"
        }
    }

    /// The large figure and the word after it: "3 months" "free", "12 days" "left", "Trial ended", "$49.50" "/ month".
    var headline: (value: String, suffix: String?) {
        guard let summary else { return ("3 months", "free") }
        switch cardKind {
        case .trial:
            let days = formatters.daysUntil(summary.trialEndsAt)
            if days > 30 { return ("3 months", "free") }
            if days < 1 { return ("Last day", nil) }
            return (days == 1 ? "1 day" : "\(days) days", "left")
        case .trialEnded:
            return ("Trial ended", nil)
        case .subscriptionEnded:
            return ("Subscription ended", nil)
        case .plan:
            return (monthlyPrice, "/ month")
        }
    }

    /// "Ends January 6, 2027", "Ended January 6, 2027", "Next payment February 6, 2027", or what went wrong and where
    /// to fix it: the link in the billing email (MS-100 D18).
    var dateLine: String? {
        guard let summary else { return nil }
        switch cardKind {
        case .trial:
            return "Ends \(formatters.longDate(summary.trialEndsAt))"
        case .trialEnded:
            return "Ended \(formatters.longDate(summary.trialEndsAt))"
        case .subscriptionEnded:
            return "Restart it from your billing email."
        case .plan:
            switch summary.subscriptionStatus {
            case .pastDue: return "The last payment failed. Update the card from your billing email."
            case .readOnly, .canceled: return "Payments stopped. Update the card from your billing email."
            case .trialing, .active: return summary.currentPeriodEnd.map { "Next payment \(formatters.longDate($0))" }
            }
        }
    }

    /// The "After trial" price row shows while there is a trial to end or one ended without a card.
    var showsAfterTrialPrice: Bool {
        cardKind == .trial || cardKind == .trialEnded
    }

    var isPromo: Bool {
        summary?.promoLifetime50 ?? false
    }

    /// "$99", struck through beside the promotion's price.
    var regularPriceText: String {
        Self.usd(Self.regularPrice)
    }

    /// "$49.50" with the lifetime promotion, else "$99".
    var monthlyPrice: String {
        Self.usd(isPromo ? Self.promoPrice : Self.regularPrice)
    }

    var monthlyPriceText: String {
        "\(monthlyPrice) / month"
    }

    static let promoBadge = "50% off for life"

    /// PRD §1: $99 per clinic per month, $49.50 with the lifetime promotion. Billed in USD (ticket MS-140).
    static let regularPrice: Decimal = 99
    static let promoPrice: Decimal = 49.5

    /// "$99" and "$49.50": whole dollars without cents.
    nonisolated static func usd(_ amount: Decimal) -> String {
        let isWhole = amount == Decimal(Int(truncating: amount as NSDecimalNumber))
        return amount.formatted(
            .currency(code: "USD").precision(.fractionLength(isWhole ? 0 : 2)).locale(Locale(identifier: "en_US"))
        )
    }

    /// "Visa ·· 4242", or nil without a card.
    var cardText: String? {
        guard let summary, let brand = summary.cardBrand else { return nil }
        guard let last4 = summary.cardLast4 else { return Self.brandName(brand) }
        return "\(Self.brandName(brand)) ·· \(last4)"
    }

    /// The payment method's status (MS-100 D18): the card, or "Not set".
    var paymentMethodText: String {
        cardText ?? "Not set"
    }

    /// Without a card, where the link to add one goes (MS-100 D18): "The link to add a card is emailed to …".
    var paymentMethodNote: String? {
        guard cardText == nil, let email = summary?.billingEmail else { return nil }
        return "The link to add a card is emailed to \(email)."
    }

    /// Stripe's brand ids as people write them.
    nonisolated static func brandName(_ brand: String) -> String {
        switch brand.lowercased() {
        case "visa": "Visa"
        case "mastercard": "Mastercard"
        case "amex", "american_express": "Amex"
        case "discover": "Discover"
        case "diners": "Diners Club"
        case "jcb": "JCB"
        case "unionpay": "UnionPay"
        case "link": "Link"
        default: brand.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// "None yet", or how many.
    var invoicesText: String {
        guard let count = summary?.invoiceCount, count > 0 else { return "None yet" }
        return "\(count)"
    }

    /// The first billing email (f34).
    var billingEmailText: String {
        summary?.billingEmail ?? ""
    }
}
