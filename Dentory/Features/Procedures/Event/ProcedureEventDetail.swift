import Foundation

/// One past procedure as the history screen opens it (PRD §6.3 From history, f14): what was done, when and by whom,
/// its cancellation if any, and the supplies it recorded, as `procedure_event_detail` reports it.
nonisolated struct ProcedureEventDetail: Codable, Equatable, Identifiable, Sendable {
    /// One supply the procedure recorded, with today's stock. A multi-use product is recorded at 0, and `takenNew`
    /// says whether a new bottle was opened for it.
    nonisolated struct Item: Codable, Equatable, Identifiable, Sendable {
        /// The product's id.
        let id: UUID
        let name: String
        let unit: String
        let tracking: TrackingMode
        let qty: Decimal
        let takenNew: Bool
        let quantity: Decimal
        let unopened: Decimal
        let openCount: Int
    }

    let id: UUID
    let templateID: UUID?
    let name: String
    let startedAt: Date
    /// The member's full name ("Sarah Mitchell"); empty when the membership is gone.
    let startedByName: String
    let cancelledAt: Date?
    let cancelledByName: String
    let cancelNote: String?
    let items: [Item]

    private enum CodingKeys: String, CodingKey {
        case id, templateID = "templateId", name, startedAt, startedByName, cancelledAt, cancelledByName, cancelNote
        case items
    }

    var isCancelled: Bool { cancelledAt != nil }

    /// What the procedure took from stock: the countable quantities plus one per bottle opened for it.
    var itemsDeducted: Int {
        items.reduce(0) { total, item in
            switch item.tracking {
            case .countable: total + NSDecimalNumber(decimal: item.qty).intValue
            case .multiUse: total + (item.takenNew ? 1 : 0)
            }
        }
    }

    /// The same procedure recording other supplies: an edit shown before the server's record comes back.
    func with(items: [Item]) -> ProcedureEventDetail {
        ProcedureEventDetail(
            id: id, templateID: templateID, name: name, startedAt: startedAt, startedByName: startedByName,
            cancelledAt: cancelledAt, cancelledByName: cancelledByName, cancelNote: cancelNote, items: items
        )
    }
}

extension ProcedureEventDetail.Item {
    /// The same product recorded with another quantity, or another answer to Take new.
    nonisolated func recorded(qty: Decimal, takenNew: Bool) -> Self {
        Self(
            id: id, name: name, unit: unit, tracking: tracking, qty: qty, takenNew: takenNew, quantity: quantity,
            unopened: unopened, openCount: openCount
        )
    }
}
