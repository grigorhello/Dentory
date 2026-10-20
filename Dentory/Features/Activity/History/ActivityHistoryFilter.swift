import Foundation

/// History's chips (f9, Appendix B `activity.filter`). Procedures include edits and cancellations; Adjustments include
/// disposals and bottles opened and finished.
nonisolated enum ActivityHistoryFilter: String, CaseIterable, Codable, Sendable {
    case all = "All"
    case receiving = "Receiving"
    case procedures = "Procedures"
    case counts = "Counts"
    case adjustments = "Adjustments"

    /// `activity_history`'s `p_filter`: nil for All.
    var parameter: String? {
        self == .all ? nil : rawValue.lowercased()
    }

    /// Whether a ledger row of `type` belongs under the chip, as the server decides it (the demo uses this).
    func includes(_ type: TransactionType) -> Bool {
        switch self {
        case .all: true
        case .receiving: type == .receiving
        case .procedures: type == .procedure || type == .cancellation
        case .counts: type == .count
        case .adjustments: type == .adjustment || type == .disposal
        }
    }
}
