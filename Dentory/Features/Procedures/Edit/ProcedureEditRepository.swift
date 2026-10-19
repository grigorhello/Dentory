import Foundation

/// Reads a template for Edit procedure, lists what Add item offers, saves the template and deletes it (MS-125).
/// Saving and deleting are admin settings, not stock changes: they go straight to the server and are not queued
/// offline.
protocol ProcedureEditRepository: Sendable {
    /// `procedure_template_detail`: throws `AppError.notFound` for a template the caller cannot see or a deleted one.
    func template(id: UUID) async throws -> ProcedureTemplateDetail

    /// `inventory_list`: the products Add item offers.
    func products(clinicID: UUID) async throws -> [ProductSummary]

    /// `procedure_template_save`: the name and the supplies in one transaction; answers the stored name.
    func save(_ request: ProcedureTemplateSaveRequest) async throws -> SavedProcedureTemplate

    /// `procedure_template_archive`: the template leaves the list; past procedures keep their data.
    func archive(templateID: UUID) async throws
}
