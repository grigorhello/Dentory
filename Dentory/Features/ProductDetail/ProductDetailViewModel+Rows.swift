import Foundation

/// The rows and lines of the expiry, bottles and history cards (f20), read from the loaded detail.
extension ProductDetailViewModel {
    /// One row of the expiry card.
    struct BatchRow: Identifiable, Equatable {
        let id: UUID
        let dateText: String
        let daysText: String
        let daysTone: StatusTone
        let quantityText: String
        let lot: String
    }

    /// One row of the bottles card.
    struct BottleRow: Identifiable, Equatable {
        let id: UUID
        let title: String
        let subtitle: String
    }

    /// One row of the history card.
    struct HistoryRow: Identifiable, Equatable {
        let id: UUID
        let deltaText: String
        let deltaTone: StatusTone
        let description: String
        let dateText: String
    }

    // MARK: - Expiry card

    /// Dated batches with stock, soonest first.
    var batchRows: [BatchRow] {
        guard let detail else { return [] }
        return detail.batches
            .filter { $0.expiryMonth != nil && $0.quantity > 0 }
            .sorted { ($0.expiryMonth ?? .distantFuture) < ($1.expiryMonth ?? .distantFuture) }
            .map { batch in
                let days = batch.expiryMonth.map(formatters.daysToExpiry(month:)) ?? 0
                return BatchRow(
                    id: batch.id,
                    dateText: batch.expiryMonth.map(formatters.shortMonth(_:)) ?? "",
                    daysText: formatters.daysLeft(days),
                    daysTone: Self.tone(forDaysLeft: days),
                    quantityText: formatters.number(batch.quantity),
                    lot: batch.lot ?? ""
                )
            }
    }

    /// Danger within 30 days or expired, warning within 90, ink beyond (PRD §6.4).
    nonisolated static func tone(forDaysLeft days: Int) -> StatusTone {
        switch days {
        case ..<31: .danger
        case ..<91: .warning
        default: .neutral
        }
    }

    /// "54 of 54 tracked · 54 expire within 90 days": N dated of M in batches, so M − N is the undated
    /// quantity (PRD §6.4). Open bottles are not batches, so a multi-use product counts its unopened stock.
    var expiryTotalLine: String {
        guard let detail else { return "" }
        let stocked = detail.batches.filter { $0.quantity > 0 }
        let dated = stocked.filter { $0.expiryMonth != nil }
        let total = stocked.reduce(Decimal(0)) { $0 + $1.quantity }
        let tracked = dated.reduce(Decimal(0)) { $0 + $1.quantity }
        let expiring = dated
            .filter { batch in batch.expiryMonth.map { formatters.daysToExpiry(month: $0) <= 90 } ?? false }
            .reduce(Decimal(0)) { $0 + $1.quantity }
        return "\(formatters.number(tracked)) of \(formatters.number(total)) tracked · "
            + "\(formatters.number(expiring)) expire within 90 days"
    }

    var unit: String { detail?.unit ?? "" }

    // MARK: - Bottles card (multi-use)

    var isMultiUse: Bool { detail?.tracking == .multiUse }

    /// "1 unopened · 2 open"
    var bottlesLine: String {
        guard let detail else { return "" }
        return "\(formatters.number(detail.unopened)) unopened · \(detail.openCount) open"
    }

    var canOpenNewBottle: Bool { (detail?.unopened ?? 0) > 0 }

    var bottleRows: [BottleRow] {
        guard let detail else { return [] }
        return detail.openBottles.map { bottle in
            let days = formatters.daysSince(bottle.openedAt)
            let when: String = switch days {
            case 0: "opened today"
            case 1: "opened 1 day ago"
            default: "opened \(days) days ago"
            }
            let title = "Open · \(PersonName.first(of: bottle.openedByName))"
            return BottleRow(id: bottle.id, title: title, subtitle: when)
        }
    }

    // MARK: - History card

    var historyRows: [HistoryRow] {
        guard let detail else { return [] }
        return detail.history.map { row in
            HistoryRow(
                id: row.id,
                deltaText: Self.deltaText(for: row, formatters: formatters),
                deltaTone: row.type == .count || row.delta == 0 ? .neutral : (row.delta < 0 ? .danger : .success),
                description: "\(Self.label(for: row)) · \(PersonName.first(of: row.byName))",
                dateText: formatters.monthDay(row.at)
            )
        }
    }

    /// "43 → 41" for a count, "+40" or "−2" otherwise, and a plain "0" for a row that moved nothing, such as
    /// "Opened a new bottle" (MS-100 D5).
    nonisolated static func deltaText(for row: StockTransaction, formatters: ClinicFormatters) -> String {
        if row.type == .count {
            return "\(formatters.number(row.quantityBefore)) → \(formatters.number(row.quantityAfter))"
        }
        if row.delta == 0 { return formatters.number(0) }
        let sign = row.delta < 0 ? "−" : "+"
        return sign + formatters.number(abs(row.delta))
    }

    /// The reason ("Damaged", "Physical count"), else the reference (the procedure, the invoice), else the kind.
    /// A reversal keeps its reason but reads "Undo · Damaged", as the engine labels it (MS-100 D10).
    nonisolated static func label(for row: StockTransaction) -> String {
        if let reference = row.referenceLabel, reference.hasPrefix(undoPrefix) { return reference }
        if let reason = row.reason, !reason.isEmpty { return reason }
        if let reference = row.referenceLabel, !reference.isEmpty { return reference }
        switch row.type {
        case .receiving: return "Received"
        case .procedure: return "Procedure"
        case .count: return "Physical count"
        case .adjustment: return "Adjustment"
        case .disposal: return "Disposed"
        case .cancellation: return "Cancelled"
        }
    }
}

extension ProductDetailViewModel {
    /// What `undo_action` puts in front of the reversed row's label.
    nonisolated static let undoPrefix = "Undo · "
}

private extension CalendarDay {
    static let distantFuture = CalendarDay(year: 9999, month: 12, day: 31)
}
