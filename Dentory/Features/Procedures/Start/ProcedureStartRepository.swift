import Foundation

/// Reads a template for Adjust, then start, lists what can be added, and starts the procedure (MS-123).
protocol ProcedureStartRepository: Sendable {
    /// `procedure_template_detail`: throws `AppError.notFound` for a template the caller cannot see or an archived one.
    func template(id: UUID) async throws -> ProcedureTemplateDetail

    /// `inventory_list`: the products Add item offers.
    func products(clinicID: UUID) async throws -> [ProductSummary]

    /// `stock_procedure_start` through the write queue: deducts each line, opens the bottles taken new and records the
    /// procedure. A start made offline is queued and replayed with the same key.
    func start(_ request: ProcedureStartRequest) async throws -> WriteOutcome
}
