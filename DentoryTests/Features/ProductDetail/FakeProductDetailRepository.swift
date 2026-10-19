import Foundation
@testable import Dentory

final class FakeProductDetailRepository: ProductDetailRepository, @unchecked Sendable {
    var detailResult: Result<ProductDetail, Error>
    var addResult: Result<UUID, Error> = .success(UUID(uuidString: "00000000-0000-4000-8000-0000000000e9") ?? UUID())
    var removeResult: Result<Void, Error> = .success(())
    var archiveResult: Result<Void, Error> = .success(())
    private(set) var archived: [UUID] = []
    var adjustResult: Result<WriteOutcome, Error> =
        .success(.applied(actionID: UUID(uuidString: "00000000-0000-4000-8000-0000000000ac") ?? UUID()))
    var undoResult: Result<Void, Error> = .success(())
    var upsertResult: Result<WriteOutcome, Error> = .success(.applied(actionID: nil))
    struct Upsert: Equatable {
        let productID: UUID
        let batchID: UUID?
        let expiryMonth: CalendarDay
        let quantity: Decimal
        let lot: String?
    }

    private(set) var upserts: [Upsert] = []
    private(set) var detailCalls: [UUID] = []
    struct Adjust: Equatable {
        let productID: UUID
        let actualQuantity: Decimal
        let reason: AdjustmentReason
        let note: String?
    }

    private(set) var adjusts: [Adjust] = []
    private(set) var undos: [UUID] = []
    struct Add: Equatable {
        let clinicID: UUID
        let productID: UUID
        let quantity: Decimal
        let userID: UUID
    }

    private(set) var adds: [Add] = []
    private(set) var removals: [UUID] = []

    init(detailResult: Result<ProductDetail, Error> = .success(.demoSeptocaine())) {
        self.detailResult = detailResult
    }

    func detail(productID: UUID) async throws -> ProductDetail {
        detailCalls.append(productID)
        return try detailResult.get()
    }

    func addToBuy(clinicID: UUID, productID: UUID, quantity: Decimal, userID: UUID) async throws -> UUID {
        adds.append(Add(clinicID: clinicID, productID: productID, quantity: quantity, userID: userID))
        return try addResult.get()
    }

    func removeFromToBuy(itemID: UUID) async throws {
        removals.append(itemID)
        try removeResult.get()
    }

    func archiveProduct(id: UUID) async throws {
        archived.append(id)
        try archiveResult.get()
    }

    func adjust(
        productID: UUID, actualQuantity: Decimal, reason: AdjustmentReason, note: String?
    ) async throws -> WriteOutcome {
        adjusts.append(Adjust(productID: productID, actualQuantity: actualQuantity, reason: reason, note: note))
        return try adjustResult.get()
    }

    func undoAdjustment(actionID: UUID) async throws {
        undos.append(actionID)
        try undoResult.get()
    }

    func upsertBatch(
        productID: UUID, batchID: UUID?, expiryMonth: CalendarDay, quantity: Decimal, lot: String?
    ) async throws -> WriteOutcome {
        upserts.append(
            Upsert(productID: productID, batchID: batchID, expiryMonth: expiryMonth, quantity: quantity, lot: lot)
        )
        return try upsertResult.get()
    }
}
