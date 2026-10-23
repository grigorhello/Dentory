import Foundation
import Supabase

extension SupabaseClient {
    /// `procedure_template_detail` (MS-123), read by Adjust, then start and by Edit procedure: the template with its
    /// supplies in order. Throws `AppError.notFound` for a template the caller cannot see, a deleted one or one that
    /// never existed.
    func procedureTemplateDetail(id: UUID) async throws -> ProcedureTemplateDetail {
        let detail: ProcedureTemplateDetail?
        do {
            detail = try await rpc("procedure_template_detail", params: ["p_template_id": id.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
        guard let detail else { throw AppError.notFound }
        return detail
    }
}
