import Foundation
@testable import Dentory

final class FakeInventoryValueRepository: InventoryValueRepository, @unchecked Sendable {
    var result: Result<InventoryValue, Error>
    private(set) var calls: [UUID] = []

    init(result: Result<InventoryValue, Error> = .success(.demo)) {
        self.result = result
    }

    func value(clinicID: UUID) async throws -> InventoryValue {
        calls.append(clinicID)
        return try result.get()
    }
}
