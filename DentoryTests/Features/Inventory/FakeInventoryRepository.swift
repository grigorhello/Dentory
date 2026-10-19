import Foundation
@testable import Dentory

final class FakeInventoryRepository: InventoryRepository, @unchecked Sendable {
    var result: Result<[ProductSummary], Error>
    private(set) var calls: [UUID] = []

    init(result: Result<[ProductSummary], Error> = .success(ProductSummary.demo)) {
        self.result = result
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        calls.append(clinicID)
        return try result.get()
    }
}
