import Foundation

/// What `to_buy_add` answers: the line and the quantity it was given.
nonisolated struct AddedToBuy: Decodable, Equatable, Sendable {
    let id: UUID
    let qty: Decimal
}
