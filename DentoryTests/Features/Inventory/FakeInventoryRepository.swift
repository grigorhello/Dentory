import Foundation
@testable import Dentory

final class FakeInventoryRepository: InventoryRepository, @unchecked Sendable {
    var result: Result<[ProductSummary], Error>
    private(set) var calls: [UUID] = []
    var applyResult: Result<WriteOutcome, Error> = .success(.applied(actionID: UUID()))
    struct Apply: Equatable {
        let clinicID: UUID
        let counts: [CountedQuantity]
    }

    private(set) var applies: [Apply] = []
    /// Runs while a count is being written, as the write coordinator's stock change does on the device (MS-150).
    var onApply: (() async -> Void)?

    init(result: Result<[ProductSummary], Error> = .success(ProductSummary.demo)) {
        self.result = result
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        calls.append(clinicID)
        return try result.get()
    }

    func applyCount(clinicID: UUID, counts: [CountedQuantity]) async throws -> WriteOutcome {
        applies.append(Apply(clinicID: clinicID, counts: counts))
        await onApply?()
        return try applyResult.get()
    }
}
