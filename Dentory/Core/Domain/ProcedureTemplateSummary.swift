import Foundation

/// One row of the Procedures list (PRD §6.3, f11): a template, how many supplies it lists, and how many of them
/// stock cannot cover ("1 not available") or would use up ("2 will run out") at their default quantity, as
/// `procedure_templates_list` reports it. Adjust, then start (MS-123) reads the template itself.
nonisolated struct ProcedureTemplateSummary: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let itemCount: Int
    let notAvailableCount: Int
    let runOutCount: Int
}
