import Foundation

/// What the New / Edit product sheet reads and writes (PRD §6.4, Appendix C `newProduct`). Products and
/// categories are written through the MS-105 policies: admins only, and only while the clinic can write.
protocol ProductFormRepository: Sendable {
    /// The clinic's categories in their order (MS-100 D13).
    func categories(clinicID: UUID) async throws -> [ProductCategory]
    /// "New category…": the clinic's category of that name, or a new one.
    func findOrCreateCategory(clinicID: UUID, name: String) async throws -> ProductCategory
    /// "Create product": the new product's id.
    func createProduct(clinicID: UUID, draft: ProductDraft) async throws -> UUID
    /// "Save changes".
    func updateProduct(id: UUID, draft: ProductDraft) async throws
}
