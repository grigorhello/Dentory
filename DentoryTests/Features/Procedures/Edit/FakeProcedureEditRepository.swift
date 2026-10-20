import Foundation
@testable import Dentory

final class FakeProcedureEditRepository: ProcedureEditRepository, @unchecked Sendable {
    var templateResult: Result<ProcedureTemplateDetail, Error>
    var productsResult: Result<[ProductSummary], Error> = .success(ProductSummary.demo + DemoSupplies.extraProducts)
    var saveError: Error?
    var archiveError: Error?
    private(set) var saves: [ProcedureTemplateSaveRequest] = []
    private(set) var archived: [UUID] = []
    private(set) var templateCalls = 0

    init(template: ProcedureTemplateDetail = ProcedureTemplateDetail.demo[0]) {
        templateResult = .success(template)
    }

    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        templateCalls += 1
        return try templateResult.get()
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try productsResult.get()
    }

    /// Answers like the server: the trimmed name, "Untitled procedure" when empty, and the number of supplies.
    func save(_ request: ProcedureTemplateSaveRequest) async throws -> SavedProcedureTemplate {
        saves.append(request)
        if let saveError { throw saveError }
        return SavedProcedureTemplate(
            id: request.templateID ?? UUID(),
            name: request.name.isEmpty ? "Untitled procedure" : request.name,
            itemCount: request.lines.count
        )
    }

    func archive(templateID: UUID) async throws {
        archived.append(templateID)
        if let archiveError { throw archiveError }
    }
}
