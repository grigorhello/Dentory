import Foundation

/// One line of an applied count: the product and the quantity counted (unopened only for a multi-use product).
nonisolated struct CountedQuantity: Equatable, Sendable {
    let productID: UUID
    let counted: Decimal
}
