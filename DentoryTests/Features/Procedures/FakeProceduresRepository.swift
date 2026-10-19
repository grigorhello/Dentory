import Foundation
@testable import Dentory

final class FakeProceduresRepository: ProceduresRepository, @unchecked Sendable {
    var templatesResult: Result<[ProcedureTemplateSummary], Error>
    /// Pages handed out in order; past the last one, an empty page.
    var historyPages: [Result<[ProcedureEventSummary], Error>]
    struct HistoryCall: Equatable {
        let clinicID: UUID
        let afterID: UUID?
        let limit: Int
    }

    private(set) var templateCalls: [UUID] = []
    private(set) var historyCalls: [HistoryCall] = []

    init(
        templates: Result<[ProcedureTemplateSummary], Error> = .success(ProcedureTemplateSummary.demo),
        historyPages: [Result<[ProcedureEventSummary], Error>] = [.success(ProcedureEventSummary.demo)]
    ) {
        templatesResult = templates
        self.historyPages = historyPages
    }

    func templates(clinicID: UUID) async throws -> [ProcedureTemplateSummary] {
        templateCalls.append(clinicID)
        return try templatesResult.get()
    }

    func history(clinicID: UUID, after: ProcedureEventSummary?, limit: Int) async throws -> [ProcedureEventSummary] {
        historyCalls.append(HistoryCall(clinicID: clinicID, afterID: after?.id, limit: limit))
        guard !historyPages.isEmpty else { return [] }
        return try historyPages.removeFirst().get()
    }
}
