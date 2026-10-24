import Foundation

/// One template as Adjust, then start opens it (PRD §6.3, MS-123): its name and its supplies in the template's
/// order, as `procedure_template_detail` reports it.
nonisolated struct ProcedureTemplateDetail: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let items: [ProcedureTemplateItem]
}
