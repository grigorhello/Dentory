import Foundation

/// History's words (f9, PRD §7): the day eyebrows, each row's reason and who-and-when lines, its delta and its tone,
/// and the empty states.
extension ActivityHistoryViewModel {
    /// "Today", "Yesterday", "Sep 30", or "Sep 30, 2025" for an earlier year.
    func dayTitle(for day: Date) -> String {
        switch formatters.daysSince(day) {
        case ...0: return "Today"
        case 1: return "Yesterday"
        default:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = formatters.timeZone
            let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: formatters.clock.now)
            return sameYear ? formatters.monthDay(day) : formatters.date(day)
        }
    }

    /// What happened: "Procedure started", "Edited usage", "Cancelled · Logged by mistake" for a procedure's row; on
    /// one product's rows the procedure's name ("Root canal"); otherwise what the engine recorded ("Invoice
    /// INV-10092", "Physical count", "Damaged", "Opened a new bottle", "Finished", "Undo · Damaged").
    func reasonText(for entry: ActivityHistoryEntry) -> String {
        if entry.refType == "undo" { return entry.refLabel ?? "Undo" }
        let isProcedureRow = entry.productID == nil
        switch entry.type {
        case .procedure:
            if isProcedureRow { return entry.isEdit ? "Edited usage" : "Procedure started" }
            return entry.refLabel ?? "Procedure"
        case .cancellation:
            if isProcedureRow {
                guard let note = entry.note, !note.isEmpty else { return "Cancelled" }
                return "Cancelled · \(note)"
            }
            return "Cancelled · \(entry.refLabel ?? "procedure")"
        case .receiving:
            return entry.refLabel ?? "Received"
        case .count:
            return entry.refLabel ?? "Physical count"
        case .adjustment:
            return entry.refLabel ?? entry.reason ?? "Adjusted"
        case .disposal:
            return "Disposed · \(entry.reason ?? "Expired")"
        }
    }

    /// "Sarah · 3:14 PM", or the time alone for someone who has left the clinic.
    func whoText(for entry: ActivityHistoryEntry) -> String {
        let time = formatters.time(entry.at)
        let name = PersonName.first(of: entry.byName)
        return name.isEmpty ? time : "\(name) · \(time)"
    }

    /// "+4", "−6", "43 → 41" for a count; nil for a change of 0, such as a bottle opened.
    func deltaText(for entry: ActivityHistoryEntry) -> String? {
        if entry.type == .count, let before = entry.qtyBefore, let after = entry.qtyAfter {
            return "\(formatters.number(before)) → \(formatters.number(after))"
        }
        if entry.delta > 0 { return "+\(formatters.number(entry.delta))" }
        if entry.delta < 0 { return "\u{2212}\(formatters.number(-entry.delta))" }
        return nil
    }

    /// Success for stock in, danger for stock out, ink for a count (f9).
    func deltaTone(for entry: ActivityHistoryEntry) -> StatusTone? {
        guard entry.type != .count else { return nil }
        if entry.delta > 0 { return .success }
        if entry.delta < 0 { return .danger }
        return nil
    }

    /// "Nothing recorded yet.", or what the chip lacks ("No counts yet.").
    var emptyText: String {
        switch filter {
        case .all: productID == nil ? "Nothing recorded yet." : "Nothing recorded for this product yet."
        case .receiving: "No deliveries received yet."
        case .procedures: "No procedures yet."
        case .counts: "No counts yet."
        case .adjustments: "No adjustments yet."
        }
    }
}
