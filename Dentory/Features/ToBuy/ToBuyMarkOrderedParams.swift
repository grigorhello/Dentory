import Foundation

/// The parameters of `to_buy_mark_ordered`: the clinic and the selected lines.
nonisolated struct ToBuyMarkOrderedParams: Encodable, Sendable {
    let pClinicId: UUID
    let pItemIds: [UUID]
}
