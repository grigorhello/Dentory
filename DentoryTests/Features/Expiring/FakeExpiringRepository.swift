import Foundation
@testable import Dentory

final class FakeExpiringRepository: ExpiringRepository, @unchecked Sendable {
    var listResult: Result<ExpiringList, Error> = .success(ExpiringList(window: 90, batches: ExpiringBatch.demo))
    var disposeResult: Result<WriteOutcome, Error> = .success(.applied(actionID: UUID()))
    var undoError: Error?
    private(set) var listCalls = 0
    private(set) var disposals: [(batchID: UUID, quantity: Decimal)] = []
    private(set) var undone: [UUID] = []

    func batches(clinicID: UUID) async throws -> ExpiringList {
        listCalls += 1
        return try listResult.get()
    }

    func dispose(batchID: UUID, quantity: Decimal) async throws -> WriteOutcome {
        disposals.append((batchID, quantity))
        return try disposeResult.get()
    }

    func undoDisposal(actionID: UUID) async throws {
        undone.append(actionID)
        if let undoError { throw undoError }
    }
}
