import Foundation

/// Home's billing notice above the tiles (MS-142, PRD §9, MS-100 G5 and D18): read-only mode once the trial ended
/// without a card or the subscription ended, and, for admins, the trial's last 7 days. Admins get "Billing", the
/// status screen; nothing points to a payment page.
nonisolated struct HomeNotice: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case readOnly, trialEnding }

    let kind: Kind
    let text: String
    /// "Billing" leads to Account, Billing: admins only.
    let showsBilling: Bool

    /// The days before the trial's end that admins are told (MS-142).
    static let warningDays = 7

    init?(session: Session, now: Date, formatters: ClinicFormatters) {
        if !session.canWrite(at: now) {
            kind = .readOnly
            showsBilling = session.isAdmin
            text = switch (session.isAdmin, session.subscriptionStatus) {
            case (true, .trialing):
                "Your free trial has ended. Add a card from the link in your billing email to keep updating stock."
            case (true, _):
                "Your subscription has ended. Restart it from the link in your billing email to keep updating stock."
            case (false, .trialing):
                "Your clinic's trial has ended. Ask your admin to add a payment method."
            case (false, _):
                "Your clinic is in read-only mode. Ask your admin to add a payment method."
            }
            return
        }
        guard session.isAdmin, session.subscriptionStatus == .trialing, let trialEndsAt = session.trialEndsAt,
              formatters.daysUntil(trialEndsAt) <= Self.warningDays else { return nil }
        kind = .trialEnding
        showsBilling = true
        text = "Your free trial ends on \(formatters.longDate(trialEndsAt)). "
            + "The link to add a card is in your billing email."
    }
}
