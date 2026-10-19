import Foundation
import Supabase

/// The template decodes straight into `ProcedureTemplateDetail` with the client's decoder (snake_case keys); the
/// start goes through `WriteCoordinator`: online now with an idempotency key, queued offline (MS-108).
struct SupabaseProcedureStartRepository: ProcedureStartRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        let detail: ProcedureTemplateDetail?
        do {
            detail = try await client
                .rpc("procedure_template_detail", params: ["p_template_id": id.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
        guard let detail else { throw AppError.notFound }
        return detail
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await client.inventoryList(clinicID: clinicID)
    }

    func start(_ request: ProcedureStartRequest) async throws -> WriteOutcome {
        try await writes.write("stock_procedure_start", params: ProcedureStartParams(request))
    }
}
