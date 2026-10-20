import Foundation
@testable import Dentory

final class FakeAccountRepository: AccountRepository, @unchecked Sendable {
    var result: Result<Int, Error>
    var exportResult: Result<String, Error>
    private(set) var calls: [UUID] = []
    private(set) var exportCalls: [UUID] = []

    init(
        result: Result<Int, Error> = .success(3),
        exportResult: Result<String, Error> = .success("sarah@dentory.test")
    ) {
        self.result = result
        self.exportResult = exportResult
    }

    func teamSize(clinicID: UUID) async throws -> Int {
        calls.append(clinicID)
        return try result.get()
    }

    func startExport(clinicID: UUID) async throws -> String {
        exportCalls.append(clinicID)
        return try exportResult.get()
    }
}
