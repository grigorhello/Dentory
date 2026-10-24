import Foundation
@testable import Dentory

final class FakeProcedureEventRepository: ProcedureEventRepository, @unchecked Sendable {
    var eventResult: Result<ProcedureEventDetail, Error>
    var productsResult: Result<[ProductSummary], Error> = .success(ProductSummary.demo + DemoSupplies.extraProducts)
    var editResult: Result<WriteOutcome, Error> = .success(.applied(actionID: UUID()))
    var cancelResult: Result<WriteOutcome, Error> = .success(.applied(actionID: UUID()))
    private(set) var eventCalls = 0
    private(set) var edits: [ProcedureUsageEdit] = []
    private(set) var cancelNotes: [String] = []

    init(event: ProcedureEventDetail = ProcedureEventDetail.demo[0]) {
        eventResult = .success(event)
    }

    func event(id: UUID) async throws -> ProcedureEventDetail {
        eventCalls += 1
        return try eventResult.get()
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try productsResult.get()
    }

    func editUsage(_ edit: ProcedureUsageEdit) async throws -> WriteOutcome {
        edits.append(edit)
        return try editResult.get()
    }

    func cancel(eventID: UUID, note: String) async throws -> WriteOutcome {
        cancelNotes.append(note)
        return try cancelResult.get()
    }
}
