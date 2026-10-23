import Foundation
@testable import Dentory

final class FakeActivityRepository: ActivityRepository, @unchecked Sendable {
    var alertsResult: Result<[ActivityAlert], Error> = .success(ActivityAlert.demo)
    var markSeenError: Error?
    /// History pages handed out in order; past the last one, an empty page.
    var historyPages: [Result<[ActivityHistoryEntry], Error>] = [.success(ActivityHistoryEntry.demo(productID: nil))]
    struct HistoryCall: Equatable {
        let filter: ActivityHistoryFilter
        let productID: UUID?
        let afterID: UUID?
        let limit: Int
    }
    private(set) var alertCalls = 0
    private(set) var seenCalls = 0
    private(set) var historyCalls: [HistoryCall] = []
    /// Runs while a history request is in flight, before it answers (a chip tapped meanwhile).
    var whileHistoryLoads: (@MainActor @Sendable () -> Void)?

    func alerts(clinicID: UUID) async throws -> [ActivityAlert] {
        alertCalls += 1
        return try alertsResult.get()
    }

    func markSeen(clinicID: UUID) async throws {
        seenCalls += 1
        if let markSeenError { throw markSeenError }
    }

    func history(
        clinicID: UUID, filter: ActivityHistoryFilter, productID: UUID?, after: ActivityHistoryEntry?, limit: Int
    ) async throws -> [ActivityHistoryEntry] {
        historyCalls.append(HistoryCall(filter: filter, productID: productID, afterID: after?.id, limit: limit))
        whileHistoryLoads?()
        guard !historyPages.isEmpty else { return [] }
        return try historyPages.removeFirst().get()
    }
}
