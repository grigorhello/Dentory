import Foundation
import Supabase

/// The answer decodes straight into `InventoryValue` with the client's decoder.
struct SupabaseInventoryValueRepository: InventoryValueRepository {
    let client: SupabaseClient

    func value(clinicID: UUID) async throws -> InventoryValue {
        do {
            return try await client
                .rpc("inventory_value", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }
}
