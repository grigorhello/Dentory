import Foundation

/// Reads one product for Product detail and puts it on the To buy list (MS-116). Stock itself only moves
/// through the engine RPCs of the later tickets.
protocol ProductDetailRepository: Sendable {
    /// `product_detail`: throws `AppError.notFound` for a product the caller cannot see or that is archived.
    func detail(productID: UUID) async throws -> ProductDetail
    /// Adds a To buy line with the suggested quantity and returns its id, for Undo.
    func addToBuy(clinicID: UUID, productID: UUID, quantity: Decimal, userID: UUID) async throws -> UUID
    /// Undo of `addToBuy`.
    func removeFromToBuy(itemID: UUID) async throws
    /// "Delete product": archives it, history kept, off the templates and the open To buy lines (Admin).
    func archiveProduct(id: UUID) async throws
}
