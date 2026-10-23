import Foundation
@testable import Dentory

final class FakeProcedureStartRepository: ProcedureStartRepository, @unchecked Sendable {
    var templateResult: Result<ProcedureTemplateDetail, Error>
    var productsResult: Result<[ProductSummary], Error> = .success(ProductSummary.demo + DemoSupplies.extraProducts)
    var startResult: Result<WriteOutcome, Error> = .success(.applied(actionID: UUID()))
    private(set) var starts: [ProcedureStartRequest] = []
    private(set) var productCalls: [UUID] = []

    init(template: ProcedureTemplateDetail = ProcedureTemplateDetail.demo[0]) {
        templateResult = .success(template)
    }

    func template(id: UUID) async throws -> ProcedureTemplateDetail {
        try templateResult.get()
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        productCalls.append(clinicID)
        return try productsResult.get()
    }

    func start(_ request: ProcedureStartRequest) async throws -> WriteOutcome {
        starts.append(request)
        return try startResult.get()
    }
}
