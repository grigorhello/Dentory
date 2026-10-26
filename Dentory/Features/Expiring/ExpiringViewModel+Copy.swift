import Foundation

/// What Expiring soon says (f27, f28, Appendix B `expiring`): the segments, the summary and each card's lines.
/// The state and the intents are in `ExpiringViewModel.swift`.
extension ExpiringViewModel {
    static let emptyText = "Nothing expires in this window."

    /// "30 days", "60 days", "90 days".
    var windowOptions: [SegmentOption<Int>] {
        Self.windows.map { SegmentOption($0, label: "\($0) days") }
    }

    /// "2 products · $186 at risk within 90 days."; nothing when no batch fits the window.
    var summary: String? {
        let batches = batches
        guard !batches.isEmpty else { return nil }
        let products = Set(batches.map(\.productID)).count
        let atRisk = batches.reduce(Decimal(0)) { $0 + $1.value }
        let noun = products == 1 ? "1 product" : "\(products) products"
        return "\(noun)\u{00A0}· \(formatters.wholeMoney(atRisk)) at risk within \(window) days."
    }

    /// "1 bottle · lot BA7 · Nov 2026": the quantity, the lot when there is one and the month, since a batch
    /// expires on its month's last day and a day would claim a precision batches lack.
    func line(for batch: ExpiringBatch) -> String {
        let parts = [
            formatters.quantity(batch.quantity, unit: batch.unit),
            batch.lot.map { "lot \($0)" },
            formatters.shortMonth(batch.expiryMonth)
        ]
        return parts.compactMap { $0 }.joined(separator: "\u{00A0}· ")
    }

    /// "59 days", "1 day", "Today", "Expired".
    func daysText(for batch: ExpiringBatch) -> String {
        switch daysLeft(for: batch) {
        case ..<0: "Expired"
        case 0: "Today"
        case 1: "1 day"
        case let days: "\(days) days"
        }
    }

    /// Danger within 30 days or once expired, warning further out (PRD §6.7).
    func daysTone(for batch: ExpiringBatch) -> StatusTone {
        daysLeft(for: batch) <= 30 ? .danger : .warning
    }

    /// "$82": the batch at the product's last unit cost.
    func valueText(for batch: ExpiringBatch) -> String {
        formatters.wholeMoney(batch.value)
    }

    /// "1 bottle Bonding agent" under "Disposed".
    func disposedDetail(_ result: DisposeBatchViewModel.Disposed) -> String {
        "\(formatters.quantity(result.quantity, unit: result.batch.unit)) \(result.batch.name)"
    }
}
