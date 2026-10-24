import Foundation
import Supabase

/// The alerts decode straight into `ActivityAlert`. The seen marker is the member's own row, not a stock write, so it
/// goes straight to the server rather than through the write queue; offline the dot simply stays.
struct SupabaseActivityRepository: ActivityRepository {
    let client: SupabaseClient

    func alerts(clinicID: UUID) async throws -> [ActivityAlert] {
        do {
            return try await client
                .rpc("activity_alerts", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func markSeen(clinicID: UUID) async throws {
        do {
            try await client.rpc("alerts_mark_seen", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
        } catch {
            throw AppError(error)
        }
    }

    func history(
        clinicID: UUID, filter: ActivityHistoryFilter, productID: UUID?, after: ActivityHistoryEntry?, limit: Int
    ) async throws -> [ActivityHistoryEntry] {
        do {
            let params = ActivityHistoryParams(
                pClinicId: clinicID, pFilter: filter.parameter, pProductId: productID, pAfterId: after?.id,
                pLimit: limit
            )
            return try await client.rpc("activity_history", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }
}
