import Foundation

/// Adjust, then start without a server: the demo clinic's five templates with the seed's supplies and today's demo
/// stock (f13: Rubber dam is out, the Endo file kit is the last one), and its products for Add item. Starting
/// succeeds after a short wait and changes nothing else.
struct DemoProcedureStartRepository: ProcedureStartRepository {
    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        try await Task.sleep(for: .milliseconds(200))
        guard let detail = ProcedureTemplateDetail.demo.first(where: { $0.id == id }) else { throw AppError.notFound }
        return detail
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await Task.sleep(for: .milliseconds(200))
        return ProductSummary.demo + DemoSupplies.extraProducts
    }

    func start(_ request: ProcedureStartRequest) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(300))
        return .applied(actionID: UUID())
    }
}
