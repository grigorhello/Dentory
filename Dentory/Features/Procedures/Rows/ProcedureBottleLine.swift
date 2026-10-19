import Foundation

/// One row under "Opened a new one?": a multi-use product, what its bottles look like ("1 open · 1 in stock", "Will
/// take 1 from stock · 0 unopened left") and whether a new one is taken for the procedure.
struct ProcedureBottleLine: Identifiable, Equatable {
    /// The product's id.
    let id: UUID
    let name: String
    let line: String
    let takesNew: Bool
}
