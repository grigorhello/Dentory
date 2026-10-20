import Foundation
@testable import Dentory

final class FakeAccountRepository: AccountRepository, @unchecked Sendable {
    var result: Result<Int, Error>
    private(set) var calls: [UUID] = []

    init(result: Result<Int, Error> = .success(3)) {
        self.result = result
    }

    func teamSize(clinicID: UUID) async throws -> Int {
        calls.append(clinicID)
        return try result.get()
    }
}
