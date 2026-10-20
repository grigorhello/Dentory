import Foundation
@testable import Dentory

final class FakeHomeRepository: HomeRepository, @unchecked Sendable {
    var result: Result<HomeSummary, Error>
    private(set) var calls: [UUID] = []

    init(result: Result<HomeSummary, Error> = .success(.demo)) {
        self.result = result
    }

    func summary(clinicID: UUID) async throws -> HomeSummary {
        calls.append(clinicID)
        return try result.get()
    }
}
