import Foundation
@testable import Dentory

final class FakeActivityRepository: ActivityRepository, @unchecked Sendable {
    var alertsResult: Result<[ActivityAlert], Error> = .success(ActivityAlert.demo)
    var markSeenError: Error?
    private(set) var alertCalls = 0
    private(set) var seenCalls = 0

    func alerts(clinicID: UUID) async throws -> [ActivityAlert] {
        alertCalls += 1
        return try alertsResult.get()
    }

    func markSeen(clinicID: UUID) async throws {
        seenCalls += 1
        if let markSeenError { throw markSeenError }
    }
}
