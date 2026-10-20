import Foundation
import Testing
@testable import Dentory

/// `billing_summary` answers one row; it decodes into `BillingSummary` with the client's decoder and survives the
/// cache's encoder.
struct BillingWireTests {
    private let json = #"""
    {"trial_ends_at": "2027-01-06T14:00:00+00:00", "subscription_status": "past_due", "has_subscription": true,
     "promo_lifetime_50": true, "card_brand": "visa", "card_last4": "4242",
     "current_period_end": "2027-02-06T14:00:00+00:00", "invoice_count": 2, "billing_email": "owner@smiledental.ca",
     "billing_email_count": 1}
    """#

    @Test func theRowDecodesIntoTheSummary() throws {
        let summary = try JSONDecoder.supabase.decode(BillingSummary.self, from: Data(json.utf8))
        #expect(summary.trialEndsAt == BillingSummary.demoTrialEnd)
        #expect(summary.subscriptionStatus == .pastDue)
        #expect(summary.hasSubscription)
        #expect(summary.promoLifetime50)
        #expect(summary.cardBrand == "visa")
        #expect(summary.cardLast4 == "4242")
        #expect(summary.currentPeriodEnd == Date(timeIntervalSince1970: 1_801_922_400))
        #expect(summary.invoiceCount == 2)
        #expect(summary.billingEmail == "owner@smiledental.ca")
        #expect(summary.billingEmailCount == 1)
    }

    @Test func aNewClinicHasNoCardAndTheCacheReadsItBack() throws {
        let row = #"""
        {"trial_ends_at": "2027-01-06T14:00:00+00:00", "subscription_status": "trialing", "has_subscription": false,
         "promo_lifetime_50": false, "card_brand": null, "card_last4": null, "current_period_end": null,
         "invoice_count": 0, "billing_email": null, "billing_email_count": 0}
        """#
        let summary = try JSONDecoder.supabase.decode(BillingSummary.self, from: Data(row.utf8))
        #expect(summary.cardBrand == nil && summary.currentPeriodEnd == nil && summary.billingEmail == nil)
        let cached = try JSONDecoder.supabase.decode(BillingSummary.self, from: JSONEncoder.supabase.encode(summary))
        #expect(cached == summary)
    }

    /// `billing_invoices` rows (MS-141) as PostgREST answers them.
    @Test func anInvoiceRowDecodes() throws {
        let rows = #"""
        [{"id": "00000000-0000-4000-8000-000000000901", "number": "DEN-0001", "issued_at": "2027-01-06T14:00:00+00:00",
          "amount_cents": 4950, "currency": "usd", "status": "paid"},
         {"id": "00000000-0000-4000-8000-000000000902", "number": null, "issued_at": "2027-02-06T14:00:00+00:00",
          "amount_cents": 4950, "currency": "usd", "status": "uncollectible"}]
        """#
        let invoices = try JSONDecoder.supabase.decode([BillingInvoice].self, from: Data(rows.utf8))
        #expect(invoices.map(\.status) == [.paid, .uncollectible])
        #expect(invoices.first?.issuedAt == BillingSummary.demoTrialEnd)
        #expect(invoices.last?.number == nil)
    }

    @Test func theSaveSendsTheClinicAndTheOtherAddresses() throws {
        let params = BillingEmailsParams(pClinicId: Session.demo.clinicID, pExtra: ["books@smiledental.ca"])
        let json = try JSONSerialization.jsonObject(with: JSONEncoder.supabase.encode(params)) as? [String: Any]
        #expect(json?["p_extra"] as? [String] == ["books@smiledental.ca"])
        #expect((json?["p_clinic_id"] as? String)?.lowercased() == Session.demo.clinicID.uuidString.lowercased())
    }
}
