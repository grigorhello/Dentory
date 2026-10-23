import Foundation
import Supabase

/// The template and the products come through the shared `SupabaseClient` reads; Save and Delete call the MS-125
/// functions, which refuse Staff and a read-only clinic.
struct SupabaseProcedureEditRepository: ProcedureEditRepository {
    let client: SupabaseClient

    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        try await client.procedureTemplateDetail(id: id)
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await client.inventoryList(clinicID: clinicID)
    }

    func save(_ request: ProcedureTemplateSaveRequest) async throws -> SavedProcedureTemplate {
        do {
            return try await client
                .rpc("procedure_template_save", params: ProcedureTemplateSaveParams(request))
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func archive(templateID: UUID) async throws {
        do {
            try await client
                .rpc("procedure_template_archive", params: ["p_template_id": templateID.uuidString.lowercased()])
                .execute()
        } catch {
            throw AppError(error)
        }
    }
}
