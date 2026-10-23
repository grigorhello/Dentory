import Foundation

/// Edit procedure without a server: the demo clinic's templates and products as Adjust, then start shows them. Save
/// answers the way the server would (a trimmed name, "Untitled procedure" when empty) and Delete succeeds; neither
/// changes the demo Procedures list.
struct DemoProcedureEditRepository: ProcedureEditRepository {
    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        try await Task.sleep(for: .milliseconds(200))
        guard let detail = ProcedureTemplateDetail.demo.first(where: { $0.id == id }) else { throw AppError.notFound }
        return detail
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await Task.sleep(for: .milliseconds(200))
        return ProductSummary.demo + DemoSupplies.extraProducts
    }

    func save(_ request: ProcedureTemplateSaveRequest) async throws -> SavedProcedureTemplate {
        try await Task.sleep(for: .milliseconds(300))
        let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return SavedProcedureTemplate(
            id: request.templateID ?? UUID(),
            name: name.isEmpty ? ProcedureEditViewModel.untitledName : name,
            itemCount: request.lines.count
        )
    }

    func archive(templateID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}
