import Foundation
import Supabase

/// Rows decode straight into the domain types with the client's decoder (`JSONDecoder.supabase`, snake_case keys):
/// the functions name their columns after the types' properties.
struct SupabaseProceduresRepository: ProceduresRepository {
    let client: SupabaseClient

    func templates(clinicID: UUID) async throws -> [ProcedureTemplateSummary] {
        do {
            return try await client
                .rpc("procedure_templates_list", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func history(clinicID: UUID, after: ProcedureEventSummary?, limit: Int) async throws -> [ProcedureEventSummary] {
        do {
            let params = ProcedureHistoryParams(pClinicId: clinicID, pAfterId: after?.id, pLimit: limit)
            return try await client.rpc("procedure_history", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }
}
