import Foundation

/// What Save changes sends from Edit usage: every supply still listed with its quantity (0 for a multi-use product),
/// and the multi-use products a new bottle is opened for. The engine writes only the difference.
nonisolated struct ProcedureUsageEdit: Equatable, Sendable {
    let eventID: UUID
    let lines: [ProcedureStartLine]
    let takeNew: [UUID]
}
