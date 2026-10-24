import Foundation
import Supabase

/// The record decodes straight into `ProcedureEventDetail`; Edit usage and Cancel go through `WriteCoordinator`:
/// online now with an idempotency key, queued offline (MS-108).
struct SupabaseProcedureEventRepository: ProcedureEventRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func event(id: UUID) async throws -> ProcedureEventDetail {
        let detail: ProcedureEventDetail?
        do {
            detail = try await client
                .rpc("procedure_event_detail", params: ["p_event_id": id.uuidString.lowercased()])
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

    func editUsage(_ edit: ProcedureUsageEdit) async throws -> WriteOutcome {
        try await writes.write("stock_procedure_edit", params: ProcedureUsageEditParams(edit))
    }

    func cancel(eventID: UUID, note: String) async throws -> WriteOutcome {
        try await writes.write("stock_procedure_cancel", params: ProcedureCancelParams(pEventId: eventID, pNote: note))
    }
}
