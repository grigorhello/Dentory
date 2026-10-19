import Foundation

/// Reads what the Procedures tab lists (MS-122).
protocol ProceduresRepository: Sendable {
    /// `procedure_templates_list`: the clinic's active templates in creation order.
    func templates(clinicID: UUID) async throws -> [ProcedureTemplateSummary]

    /// `procedure_history`: a page of past procedures, newest first. `after` is the last row of the previous page;
    /// nil asks for the first.
    func history(clinicID: UUID, after: ProcedureEventSummary?, limit: Int) async throws -> [ProcedureEventSummary]
}
