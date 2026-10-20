import Foundation
import Supabase

/// Counts the clinic's active memberships with a head request: no rows travel, only the count. Every member may
/// read their clinic's memberships (MS-105).
struct SupabaseAccountRepository: AccountRepository {
    let client: SupabaseClient

    func teamSize(clinicID: UUID) async throws -> Int {
        do {
            let response = try await client.from("memberships")
                .select("id", head: true, count: .exact)
                .eq("clinic_id", value: clinicID.uuidString)
                .eq("status", value: "active")
                .execute()
            return response.count ?? 0
        } catch {
            throw AppError(error)
        }
    }
}
