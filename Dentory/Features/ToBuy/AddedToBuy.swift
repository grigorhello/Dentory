import Foundation

/// What `to_buy_add` answers: the line, its quantity, and whether this call created it. A product already on the
/// list keeps its line, which Undo must not delete.
nonisolated struct AddedToBuy: Decodable, Equatable, Sendable {
    let id: UUID
    let qty: Decimal
    let created: Bool
}
