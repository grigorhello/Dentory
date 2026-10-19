/// Why a quantity was adjusted by hand (PRD Appendix C `adjust`). The raw value is what `stock_adjust`
/// accepts and what the ledger row shows as its reason.
nonisolated enum AdjustmentReason: String, CaseIterable, Codable, Sendable {
    case physicalCount = "Physical count"
    case expired = "Expired"
    case damaged = "Damaged"
    case waste = "Waste"
    case missing = "Missing"
    case returned = "Returned"
    case dataCorrection = "Data correction"
    case other = "Other"

    var label: String { rawValue }

    /// "Other" says nothing on its own, so it needs a note.
    var requiresNote: Bool { self == .other }
}
