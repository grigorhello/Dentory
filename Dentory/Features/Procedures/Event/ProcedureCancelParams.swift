import Foundation

/// The parameters of `stock_procedure_cancel`; the coordinator adds `p_idempotency_key`.
nonisolated struct ProcedureCancelParams: Encodable, Sendable {
    let pEventId: UUID
    let pNote: String
}
