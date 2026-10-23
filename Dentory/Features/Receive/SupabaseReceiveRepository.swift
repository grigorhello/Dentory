import Foundation
import Supabase

/// The overview decodes straight into `ReceiveOverview`.
struct SupabaseReceiveRepository: ReceiveRepository {
    let client: SupabaseClient

    func overview(clinicID: UUID) async throws -> ReceiveOverview {
        do {
            return try await client
                .rpc("receive_overview", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }
}
