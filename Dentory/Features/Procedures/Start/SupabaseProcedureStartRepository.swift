import Foundation
import Supabase

/// The template and the products come through the shared `SupabaseClient` reads; the
/// start goes through `WriteCoordinator`: online now with an idempotency key, queued offline (MS-108).
struct SupabaseProcedureStartRepository: ProcedureStartRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        try await client.procedureTemplateDetail(id: id)
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await client.inventoryList(clinicID: clinicID)
    }

    func start(_ request: ProcedureStartRequest) async throws -> WriteOutcome {
        try await writes.write("stock_procedure_start", params: ProcedureStartParams(request))
    }
}
