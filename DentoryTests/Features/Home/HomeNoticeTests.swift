import Foundation
import Testing
@testable import Dentory

/// Home's billing notice (MS-142): read-only mode for every member, the trial's last 7 days for admins.
struct HomeNoticeTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let day: TimeInterval = 86_400

    private func session(
        role: MembershipRole = .admin, status: SubscriptionStatus = .trialing, trialEndsIn days: Double
    ) -> Session {
        var session = Session.demo(role: role)
        session.subscriptionStatus = status
        session.trialEndsAt = Session.demoNow.addingTimeInterval(days * day)
        return session
    }

    private func notice(_ session: Session) -> HomeNotice? {
        HomeNotice(session: session, now: Session.demoNow, formatters: formatters)
    }

    @Test func anEndedTrialTellsTheAdminWhereTheCardGoesAndOffersBilling() {
        let notice = notice(session(trialEndsIn: -1))
        #expect(notice?.kind == .readOnly)
        #expect(notice?.text
            == "Your free trial has ended. Add a card from the link in your billing email to keep updating stock.")
        #expect(notice?.showsBilling == true)
    }

    @Test func staffAreToldToAskTheirAdmin() {
        let notice = notice(session(role: .staff, trialEndsIn: -1))
        #expect(notice?.text == "Your clinic's trial has ended. Ask your admin to add a payment method.")
        #expect(notice?.showsBilling == false, "Billing is the admin's")
        let ended = self.notice(session(role: .staff, status: .canceled, trialEndsIn: -60))
        #expect(ended?.text == "Your clinic is in read-only mode. Ask your admin to add a payment method.")
    }

    /// Stripe stopped retrying a failed card (unpaid or paused): the plan is not over, the card needs updating, as
    /// Billing says (MS-142 review).
    @Test func stoppedPaymentsAskForTheCardToBeUpdated() {
        let notice = notice(session(status: .readOnly, trialEndsIn: -60))
        #expect(notice?.kind == .readOnly)
        #expect(notice?.text
            == "Payments stopped. Update the card from the link in your billing email to keep updating stock.")
        #expect(notice?.showsBilling == true)
        #expect(self.notice(session(role: .staff, status: .readOnly, trialEndsIn: -60))?.text
            == "Your clinic is in read-only mode. Ask your admin to update the payment method.")
    }

    @Test func anEndedSubscriptionIsNotCalledATrial() {
        let notice = notice(session(status: .canceled, trialEndsIn: -60))
        #expect(notice?.kind == .readOnly)
        #expect(notice?.text
            == "Your subscription has ended. Restart it from the link in your billing email to keep updating stock.")
    }

    @Test func theTrialsLastWeekIsAnnouncedToAdminsOnly() {
        let notice = notice(session(trialEndsIn: 5))
        #expect(notice?.kind == .trialEnding)
        #expect(notice?.text
            == "Your free trial ends on October 7, 2026. The link to add a card is in your billing email.")
        #expect(notice?.showsBilling == true)
        #expect(self.notice(session(role: .staff, trialEndsIn: 5)) == nil)
        #expect(self.notice(session(trialEndsIn: 8)) == nil, "More than 7 days left")
        #expect(self.notice(session(status: .active, trialEndsIn: 5)) == nil, "A card is already on file")
    }
}
