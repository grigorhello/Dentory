import Foundation

/// The products a delivery can go into: Receive manually's Choose product (MS-127) and Review invoice's Which product
/// is this? (MS-130). Admin only: the server refuses anyone else.
protocol ReceivableProductsRepository: Sendable {
    /// `receive_products`: the clinic's active products with their pack and stock.
    func products(clinicID: UUID) async throws -> [ReceivableProduct]
}
