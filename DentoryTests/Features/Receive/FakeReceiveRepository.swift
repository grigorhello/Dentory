import Foundation
@testable import Dentory

final class FakeReceiveRepository: ReceiveRepository, @unchecked Sendable {
    var result: Result<ReceiveOverview, Error> = .success(.demo(now: Session.demoNow))
    private(set) var calls: [UUID] = []

    func overview(clinicID: UUID) async throws -> ReceiveOverview {
        calls.append(clinicID)
        return try result.get()
    }
}
