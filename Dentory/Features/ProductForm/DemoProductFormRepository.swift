import Foundation

/// The sheet without a server: categories and products live in the shared demo store, so a product
/// created or edited here shows in the Inventory list and Product detail of the same launch.
struct DemoProductFormRepository: ProductFormRepository {
    let store: DemoProductStore

    func categories(clinicID: UUID) async throws -> [ProductCategory] {
        try await Task.sleep(for: .milliseconds(100))
        return store.categories
    }

    func findOrCreateCategory(clinicID: UUID, name: String) async throws -> ProductCategory {
        try await Task.sleep(for: .milliseconds(100))
        return store.findOrCreateCategory(named: name)
    }

    func createProduct(clinicID: UUID, draft: ProductDraft) async throws -> UUID {
        try await Task.sleep(for: .milliseconds(200))
        return store.create(draft)
    }

    func updateProduct(id: UUID, draft: ProductDraft) async throws {
        try await Task.sleep(for: .milliseconds(200))
        guard store.update(id: id, draft: draft) else { throw AppError.notFound }
    }
}
