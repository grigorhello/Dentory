import Foundation

/// The parameters of `undo_action` (MS-106), which reverses an adjustment, a receiving or a disposal within 10
/// seconds for the person who made it; the coordinator adds `p_idempotency_key`.
nonisolated struct UndoActionParams: Encodable, Sendable {
    let pActionId: UUID
}
