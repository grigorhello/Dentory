import Foundation
@testable import Dentory

final class FakeProductFormRepository: ProductFormRepository, @unchecked Sendable {
    var categoriesResult: Result<[ProductCategory], Error> = .success(ProductCategory.demo)
    var createResult: Result<UUID, Error> = .success(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1") ?? UUID())
    var updateResult: Result<Void, Error> = .success(())
    var findOrCreateResult: Result<ProductCategory, Error> = .success(
        ProductCategory(id: UUID(uuidString: "00000000-0000-4000-8000-0000000000f2") ?? UUID(), name: "Orthodontics")
    )
    private(set) var categoryCalls: [UUID] = []
    private(set) var findOrCreateCalls: [String] = []
    private(set) var creates: [ProductDraft] = []
    private(set) var updates: [(id: UUID, draft: ProductDraft)] = []

    func categories(clinicID: UUID) async throws -> [ProductCategory] {
        categoryCalls.append(clinicID)
        return try categoriesResult.get()
    }

    func findOrCreateCategory(clinicID: UUID, name: String) async throws -> ProductCategory {
        findOrCreateCalls.append(name)
        return try findOrCreateResult.get()
    }

    func createProduct(clinicID: UUID, draft: ProductDraft) async throws -> UUID {
        creates.append(draft)
        return try createResult.get()
    }

    func updateProduct(id: UUID, draft: ProductDraft) async throws {
        updates.append((id: id, draft: draft))
        try updateResult.get()
    }
}
