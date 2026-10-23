import Foundation

/// One supply of a started procedure: the product and the quantity it takes.
nonisolated struct ProcedureStartLine: Equatable, Sendable {
    let productID: UUID
    let quantity: Decimal
}
