import Foundation

/// The demo clinic's billing as f34 and f35 draw it: three months free ending January 6, 2027, the lifetime promotion,
/// a Visa card, no invoices yet and the owner's address, kept in memory as the billing emails change. The trial may end
/// on another day (MS-142); `launched()` (App/DemoTrial.swift) reads the launch arguments.
final class DemoBillingRepository: BillingRepository, @unchecked Sendable {
    let hasCard: Bool
    let trialEndsAt: Date
    private let demoInvoices: [BillingInvoice]
    private var emails = ["owner@smiledental.ca"]
    private let lock = NSLock()

    init(hasCard: Bool = true, trialEndsAt: Date = BillingSummary.demoTrialEnd, withInvoices: Bool = false) {
        self.hasCard = hasCard
        self.trialEndsAt = trialEndsAt
        demoInvoices = withInvoices ? BillingInvoice.demo : []
    }

    func summary(clinicID: UUID) async throws -> BillingSummary {
        let current = lock.withLock { self.emails }
        return BillingSummary.demo(
            hasCard: hasCard, trialEndsAt: trialEndsAt, invoiceCount: demoInvoices.count, emails: current
        )
    }

    func invoices(clinicID: UUID) async throws -> [BillingInvoice] {
        demoInvoices
    }

    func billingEmails(clinicID: UUID) async throws -> [String] {
        lock.withLock { emails }
    }

    func saveBillingEmails(clinicID: UUID, extra: [String]) async throws -> [String] {
        lock.withLock {
            emails = [emails[0]] + extra.map { $0.lowercased() }.filter { $0 != emails[0] }
            return emails
        }
    }
}

extension BillingInvoice {
    /// Three months after the trial, newest first, for screenshots: the newest still open, the two before it paid.
    nonisolated static let demo: [BillingInvoice] = (0..<3).map { month in
        BillingInvoice(
            id: UUID(uuidString: "00000000-0000-4000-8000-00000000090\(month)") ?? UUID(),
            number: "DEN-000\(3 - month)",
            issuedAt: BillingSummary.demoTrialEnd.addingTimeInterval(Double(2 - month) * 31 * 86_400),
            amountCents: 4950,
            currency: "usd",
            status: month == 0 ? .open : .paid
        )
    }
}

extension BillingSummary {
    /// f34: January 6, 2027 at 9 am in Toronto.
    nonisolated static let demoTrialEnd = Date(timeIntervalSince1970: 1_799_244_000)

    nonisolated static func demo(
        hasCard: Bool, trialEndsAt: Date = demoTrialEnd, invoiceCount: Int = 0,
        emails: [String] = ["owner@smiledental.ca"]
    ) -> BillingSummary {
        BillingSummary(
            trialEndsAt: trialEndsAt,
            subscriptionStatus: hasCard ? .active : .trialing,
            hasSubscription: hasCard,
            promoLifetime50: true,
            cardBrand: hasCard ? "visa" : nil,
            cardLast4: hasCard ? "4242" : nil,
            currentPeriodEnd: hasCard ? demoTrialEnd : nil,
            invoiceCount: invoiceCount,
            billingEmail: emails.first,
            billingEmailCount: emails.count
        )
    }
}
