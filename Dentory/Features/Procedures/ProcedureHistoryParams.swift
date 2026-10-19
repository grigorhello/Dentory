import Foundation

/// The parameters of `procedure_history`. The first page sends the cursor as nulls rather than leaving it out,
/// so PostgREST always finds the function by its full parameter list.
nonisolated struct ProcedureHistoryParams: Encodable, Sendable {
    let pClinicId: UUID
    let pBeforeAt: Date?
    let pBeforeId: UUID?
    let pLimit: Int

    private enum CodingKeys: String, CodingKey {
        case pClinicId, pBeforeAt, pBeforeId, pLimit
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pClinicId, forKey: .pClinicId)
        try container.encode(pBeforeAt, forKey: .pBeforeAt)
        try container.encode(pBeforeId, forKey: .pBeforeId)
        try container.encode(pLimit, forKey: .pLimit)
    }
}
