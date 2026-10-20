import Foundation

/// The line under a supply's name on a procedure: "0 will remain" in warning, "Not available · 0 in stock" in danger
/// (Adjust, then start), or "Recorded 2" in the secondary color (Edit usage, `tone` nil).
struct ProcedureLineNote: Equatable {
    let text: String
    var tone: StatusTone?
}
