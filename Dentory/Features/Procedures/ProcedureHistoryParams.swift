import Foundation

/// The parameters of `procedure_history`. The next page names the previous page's last row by its id only: the
/// server looks up that row's exact time, which a date sent from here would round to the second. The first page
/// sends the cursor as null rather than leaving it out, so PostgREST always finds the function by its full
/// parameter list.
nonisolated struct ProcedureHistoryParams: Encodable, Sendable {
    let pClinicId: UUID
    let pAfterId: UUID?
    let pLimit: Int

    private enum CodingKeys: String, CodingKey {
        case pClinicId, pAfterId, pLimit
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pClinicId, forKey: .pClinicId)
        try container.encode(pAfterId, forKey: .pAfterId)
        try container.encode(pLimit, forKey: .pLimit)
    }
}
