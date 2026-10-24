import Foundation

/// `-trial ended` starts the demo clinic in read-only mode, its free trial over without a card; `-trial ending` in the
/// trial's last days (MS-142, screenshots and UI tests).
enum DemoTrial: String {
    case ended, ending

    static var launched: DemoTrial? {
        UserDefaults.standard.string(forKey: "trial").flatMap(Self.init(rawValue:))
    }

    /// The day before the frames' moment, or 5 days after it.
    var trialEndsAt: Date {
        switch self {
        case .ended: Session.demoNow.addingTimeInterval(-86_400)
        case .ending: Session.demoNow.addingTimeInterval(5 * 86_400)
        }
    }
}

extension DemoBillingRepository {
    /// Billing as the launch arguments ask: `-billingNoCard YES` before a card is added, `-trial ended` or
    /// `-trial ending` without one, `-billingInvoices YES` with three months of invoices (screenshots, UI tests).
    static func launched() -> DemoBillingRepository {
        DemoBillingRepository(
            hasCard: !UserDefaults.standard.bool(forKey: "billingNoCard") && DemoTrial.launched == nil,
            trialEndsAt: DemoTrial.launched?.trialEndsAt ?? BillingSummary.demoTrialEnd,
            withInvoices: UserDefaults.standard.bool(forKey: "billingInvoices")
        )
    }
}
