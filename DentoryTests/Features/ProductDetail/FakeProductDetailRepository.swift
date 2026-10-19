import Foundation
@testable import Dentory

final class FakeProductDetailRepository: ProductDetailRepository, @unchecked Sendable {
    var detailResult: Result<ProductDetail, Error>
    var addResult: Result<UUID, Error> = .success(UUID(uuidString: "00000000-0000-4000-8000-0000000000e9") ?? UUID())
    var removeResult: Result<Void, Error> = .success(())
    private(set) var detailCalls: [UUID] = []
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
}
