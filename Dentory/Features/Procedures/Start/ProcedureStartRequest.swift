import Foundation

/// What Start procedure sends: every supply with its quantity (0 for a multi-use product used from its open one) and
/// the multi-use products taken new.
nonisolated struct ProcedureStartRequest: Equatable, Sendable {
    let clinicID: UUID
    let templateID: UUID
    let name: String
    let lines: [ProcedureStartLine]
    let takeNew: [UUID]
}
