import Foundation
import Supabase

/// `billing_summary`, the one row Billing shows.
struct SupabaseBillingRepository: BillingRepository {
    let client: SupabaseClient

    func summary(clinicID: UUID) async throws -> BillingSummary {
        do {
            return try await client
                .rpc("billing_summary", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .single()
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }
}
