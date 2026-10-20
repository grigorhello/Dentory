import Foundation

/// The parameters of `activity_history`. The next page names the previous page's last row by its id only: the server
/// looks up that row's exact time, which a date sent from here would round. Absent values go out as nulls, so
/// PostgREST always finds the function by its full parameter list.
nonisolated struct ActivityHistoryParams: Encodable, Sendable {
    let pClinicId: UUID
    let pFilter: String?
    let pProductId: UUID?
    let pAfterId: UUID?
    let pLimit: Int

    private enum CodingKeys: String, CodingKey {
        case pClinicId, pFilter, pProductId, pAfterId, pLimit
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pClinicId, forKey: .pClinicId)
        try container.encode(pFilter, forKey: .pFilter)
        try container.encode(pProductId, forKey: .pProductId)
        try container.encode(pAfterId, forKey: .pAfterId)
        try container.encode(pLimit, forKey: .pLimit)
    }
}
