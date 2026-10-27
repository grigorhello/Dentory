import Foundation

/// What Activity says (f8, PRD §6.8, Appendix B `activity`): the segments, each alert's sentence, its dot and when it
/// opened. The state and the intents are in `ActivityViewModel.swift`.
extension ActivityViewModel {
    static let emptyText = "Nothing needs attention."
    /// "Alerts · 3", "History".
    var segmentOptions: [SegmentOption<Segment>] {
        [SegmentOption(.alerts, label: "Alerts", count: alerts.count), SegmentOption(.history, label: "History")]
    }

    /// "Rubber dam latex-free is out of stock.", "Endo file kit #15-40 is low · 1 left, minimum 3.", "Bonding agent
    /// expires in 59 days." (with the lot when several of the product's batches are expiring), "Gutta percha F2 is
    /// missing expiry information.", "Delivery from Patterson is read and waiting for review."
    func sentence(for alert: ActivityAlert) -> String {
        let name = alert.name ?? ""
        switch alert.kind {
        case .outOfStock:
            return "\(name) is out of stock."
        case .low:
            let left = (alert.tracking == .multiUse ? alert.unopened : alert.quantity) ?? 0
            let minimum = formatters.number(alert.minimum ?? 0)
            return Caption.joined("\(name) is low", "\(formatters.number(left)) left, minimum \(minimum).")
        case .expiring:
            let subject = alert.expiringBatches > 1 ? alert.lot.map { "\(name) lot \($0)" } ?? name : name
            return "\(subject) \(expiry(daysLeft(for: alert)))."
        case .missingExpiry:
            return "\(name) is missing expiry information."
        case .invoiceReady:
            guard let supplier = alert.supplier, !supplier.isEmpty else {
                return "A delivery is read and waiting for review."
            }
            return "Delivery from \(supplier) is read and waiting for review."
        }
    }

    /// "Today · 8:40 AM", "Yesterday", "Sep 28".
    func whenText(for alert: ActivityAlert) -> String {
        switch formatters.daysSince(alert.openedAt) {
        case ...0: "Today\(Caption.separator)\(formatters.time(alert.openedAt))"
        case 1: "Yesterday"
        default: formatters.monthDay(alert.openedAt)
        }
    }

    /// Danger for out of stock and a batch within 30 days, warning for low and a later expiry, info for missing
    /// expiry and a delivery waiting for review (PRD §5).
    func dotTone(for alert: ActivityAlert) -> StatusTone {
        switch alert.kind {
        case .outOfStock: .danger
        case .expiring: daysLeft(for: alert) <= 30 ? .danger : .warning
        case .low: .warning
        case .missingExpiry, .invoiceReady: .info
        }
    }

    /// Days to the last day of the batch's month, as `days_to_expiry` counts them.
    private func daysLeft(for alert: ActivityAlert) -> Int {
        alert.expiryMonth.map(formatters.daysToExpiry(month:)) ?? 0
    }

    private func expiry(_ days: Int) -> String {
        switch days {
        case ..<0: "has expired"
        case 0: "expires today"
        case 1: "expires in 1 day"
        default: "expires in \(days) days"
        }
    }
}
