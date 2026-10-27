import Foundation

/// What a past procedure says (f14, Appendix B `procDetail`, Appendix C `cancelProcedure`): the banner, each row's
/// figure, the lines while editing, the cancel sheet and the toasts. The state and the intents are in
/// `ProcedureEventViewModel.swift`.
extension ProcedureEventViewModel {
    static let editingNotice = "Changes adjust inventory and are recorded in Activity."

    var title: String { detail?.name ?? "Procedure" }

    /// "10 items deducted · Oct 1 · 3:14 PM · Sarah".
    var summary: String {
        guard let detail else { return "" }
        let parts = [
            Self.items(detail.itemsDeducted) + " deducted", formatters.dateTime(detail.startedAt),
            PersonName.first(of: detail.startedByName)
        ]
        return Caption.joined(parts)
    }

    /// "Cancelled · Oct 2 · 9:41 AM · Sarah: Logged by mistake".
    var cancelledText: String? {
        guard let detail, let cancelledAt = detail.cancelledAt else { return nil }
        let head = Caption.joined(
            "Cancelled", formatters.dateTime(cancelledAt), PersonName.first(of: detail.cancelledByName)
        )
        guard let note = detail.cancelNote, !note.isEmpty else { return head }
        return "\(head): \(note)"
    }

    /// The Used column: the countable quantity, or what a multi-use product did.
    func usage(of item: ProcedureEventDetail.Item) -> String {
        switch item.tracking {
        case .countable: formatters.number(item.qty)
        case .multiUse: item.takenNew ? "Opened a new bottle" : "Used from open bottle"
        }
    }

    /// While editing: "Recorded 2" under a quantity that differs from the record.
    func note(for supply: Supply) -> ProcedureLineNote? {
        supply.quantity == supply.recorded ? nil : ProcedureLineNote(text: "Recorded \(supply.recorded)")
    }

    /// The bottles taken new, listed with the supplies as one item each.
    var takenNew: [Bottle] { bottles.filter(\.takesNew) }

    /// The recorded multi-use products, listed under "Opened a new one?"; one Add item brought in is listed with the
    /// supplies only.
    var bottleLines: [ProcedureBottleLine] {
        bottles.filter { !$0.isAdded }.map {
            ProcedureBottleLine(id: $0.id, name: $0.item.name, line: line(for: $0), takesNew: $0.takesNew)
        }
    }

    /// "Opened a new bottle", "Will take 1 from stock · 1 unopened left", "Goes back to stock", "1 open · 1 in stock".
    func line(for bottle: Bottle) -> String {
        switch (bottle.takesNew, bottle.recordedTakesNew) {
        case (true, true):
            "Opened a new bottle"
        case (true, false):
            Caption.joined(
                "Will take 1 from stock", "\(formatters.number(max(bottle.item.unopened - 1, 0))) unopened left"
            )
        case (false, true):
            "Goes back to stock"
        case (false, false):
            "\(bottle.item.openCount) open\(Caption.separator)\(formatters.number(bottle.item.unopened)) in stock"
        }
    }

    /// "Cancel Root canal?".
    var cancelTitle: String { "Cancel \(title)?" }

    /// "10 items will be returned to inventory. Stock levels update immediately."
    var cancelWarning: String {
        let count = detail?.itemsDeducted ?? 0
        let verb = count == 1 ? "1 item will" : "\(count) items will"
        return "\(verb) be returned to inventory. Stock levels update immediately."
    }

    /// "40 needles in stock" under a product in Add item; "1 unopened · 2 open" for a multi-use one, and "Out of
    /// stock" once + found nothing unopened.
    func addCaption(for product: ProductSummary) -> String? {
        if product.id == outOfStockProductID { return "Out of stock" }
        return switch product.tracking {
        case .countable: "\(formatters.quantity(product.quantity, unit: product.unit)) in stock"
        case .multiUse: "\(formatters.number(product.unopened)) unopened\(Caption.separator)\(product.openCount) open"
        }
    }

    func addCaptionTone(for product: ProductSummary) -> StatusTone? {
        product.id == outOfStockProductID ? .danger : nil
    }

    /// What Add item says with nothing to list: nothing while the products load, and how to retry when they failed.
    var addItemEmptyText: String {
        if hasLoadedProducts { return "No products match." }
        return productsFailed ? "Couldn't load products. Reopen Add item to try again." : ""
    }

    /// "10 items", "1 item".
    static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    /// "10 items returned" under "{name} cancelled".
    static func itemsReturned(_ count: Int) -> String {
        "\(items(count)) returned"
    }
}
