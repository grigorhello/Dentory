import Foundation

/// The usage being edited on a past procedure (f14 editing; PRD §6.3 From history): each countable supply with its
/// quantity and what was recorded, and each multi-use product with whether a new bottle is opened for it. Save sends
/// it whole as `ProcedureUsageEdit`, and the engine writes only the difference.
nonisolated struct ProcedureUsageDraft: Equatable, Sendable {
    /// A countable supply: what it uses now and what was recorded.
    nonisolated struct Supply: Identifiable, Equatable, Sendable {
        let item: ProcedureEventDetail.Item
        var quantity: Int
        let recorded: Int
        var id: UUID { item.id }
    }

    /// A multi-use product: whether a new bottle is opened for the procedure, and whether one was.
    nonisolated struct Bottle: Identifiable, Equatable, Sendable {
        let item: ProcedureEventDetail.Item
        var takesNew: Bool
        let recordedTakesNew: Bool
        /// Not recorded: Add item put it here taken new, and turning Take new off removes it.
        var isAdded = false
        var id: UUID { item.id }
    }

    /// What a tap on Take new did.
    nonisolated enum TakeNewResult: Equatable, Sendable {
        case toggled
        /// A product Add item brought in left the procedure.
        case removed
        /// Nothing unopened to take a new one from; nothing changed.
        case outOfStock
    }

    private(set) var supplies: [Supply] = []
    private(set) var bottles: [Bottle] = []
    private var recordedSupplies: Set<UUID> = []

    init() {}

    /// The usage as the procedure recorded it.
    init(recording items: [ProcedureEventDetail.Item]) {
        supplies = items.filter { $0.tracking == .countable }.map { item in
            let recorded = Self.wholeNumber(item.qty)
            return Supply(item: item, quantity: recorded, recorded: recorded)
        }
        bottles = items.filter { $0.tracking == .multiUse }.map { item in
            Bottle(item: item, takesNew: item.takenNew, recordedTakesNew: item.takenNew)
        }
        recordedSupplies = Set(supplies.map(\.id))
    }

    /// The stepper's value, never below 0.
    subscript(quantityOf id: UUID) -> Int {
        get { supplies.first { $0.id == id }?.quantity ?? 0 }
        set {
            guard let index = supplies.firstIndex(where: { $0.id == id }) else { return }
            supplies[index].quantity = max(newValue, 0)
        }
    }

    func contains(_ id: UUID) -> Bool {
        supplies.contains { $0.id == id } || bottles.contains { $0.id == id }
    }

    /// The X: the supply leaves the record when the edit is saved, and its quantity goes back to stock.
    mutating func remove(_ id: UUID) {
        supplies.removeAll { $0.id == id }
    }

    /// Add item, as on Adjust, then start: a countable product joins with 1 and a multi-use one is taken new. Returns
    /// false, adding nothing, for a multi-use product with nothing unopened.
    mutating func add(_ product: ProductSummary) -> Bool {
        guard !contains(product.id) else { return true }
        let item = ProcedureEventDetail.Item(
            id: product.id, name: product.name, unit: product.unit, tracking: product.tracking, qty: 0,
            takenNew: false, quantity: product.quantity, unopened: product.unopened, openCount: product.openCount
        )
        switch product.tracking {
        case .countable:
            supplies.append(Supply(item: item, quantity: 1, recorded: 0))
        case .multiUse:
            guard product.unopened > 0 else { return false }
            bottles.append(Bottle(item: item, takesNew: true, recordedTakesNew: false, isAdded: true))
        }
        return true
    }

    /// On: a new bottle is opened for the procedure. Off: a bottle opened for it goes back to stock, and a product
    /// Add item brought in leaves.
    mutating func toggleTakeNew(_ id: UUID) -> TakeNewResult? {
        guard let index = bottles.firstIndex(where: { $0.id == id }) else { return nil }
        let bottle = bottles[index]
        if bottle.isAdded && bottle.takesNew {
            bottles.remove(at: index)
            return .removed
        }
        if !bottle.takesNew && !bottle.recordedTakesNew && bottle.item.unopened <= 0 { return .outOfStock }
        bottles[index].takesNew.toggle()
        return .toggled
    }

    /// Anything Save would write: a quantity, a supply removed or added, a bottle taken new or given back.
    var hasChanges: Bool {
        supplies.contains { $0.quantity != $0.recorded }
            || Set(supplies.map(\.id)) != recordedSupplies
            || bottles.contains { $0.takesNew != $0.recordedTakesNew || $0.isAdded }
    }

    /// What Save sends: every supply still listed with its quantity, each multi-use product at 0, and the bottles
    /// taken new.
    func edit(eventID: UUID) -> ProcedureUsageEdit {
        ProcedureUsageEdit(
            eventID: eventID,
            lines: supplies.map { ProcedureStartLine(productID: $0.id, quantity: Decimal($0.quantity)) }
                + bottles.map { ProcedureStartLine(productID: $0.id, quantity: 0) },
            takeNew: bottles.filter(\.takesNew).map(\.id)
        )
    }

    /// The record as edited, shown until the server's comes back: a supply at 0 leaves it.
    var recordedItems: [ProcedureEventDetail.Item] {
        supplies.filter { $0.quantity > 0 }.map { $0.item.recorded(qty: Decimal($0.quantity), takenNew: false) }
            + bottles.map { $0.item.recorded(qty: 0, takenNew: $0.takesNew) }
    }

    private static func wholeNumber(_ value: Decimal) -> Int {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return max(NSDecimalNumber(decimal: rounded).intValue, 0)
    }
}
