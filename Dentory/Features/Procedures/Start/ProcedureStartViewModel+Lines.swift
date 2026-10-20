import Foundation

/// What Adjust, then start shows (f13, Appendix B `procDetail`): the summary, each row's warning, the bottle lines,
/// Add item's captions and the Start label. The state and the intents are in `ProcedureStartViewModel.swift`.
extension ProcedureStartViewModel {
    /// A row's warning: "0 will remain" in warning, "Not available · 0 in stock" in danger.
    struct Warning: Equatable {
        let text: String
        let tone: StatusTone
    }

    /// Every supply of this procedure: the countable rows and the multi-use products.
    var supplyCount: Int { supplies.count + bottles.count }

    /// What Start deducts: the countable quantities plus one per bottle taken new.
    var itemCount: Int {
        supplies.reduce(0) { $0 + $1.quantity } + bottles.count(where: \.takesNew)
    }

    /// Countable rows stock cannot cover.
    var notAvailableCount: Int {
        supplies.count(where: { $0.quantity > 0 && Decimal($0.quantity) > $0.item.quantity })
    }

    /// Countable rows that use stock up, and bottles taken new that are the last unopened one.
    var willReachZeroCount: Int {
        supplies.count(where: { $0.quantity > 0 && Decimal($0.quantity) == $0.item.quantity })
            + bottles.count(where: { $0.takesNew && $0.item.unopened == 1 })
    }

    /// "12 supplies · 1 not available. Add or remove items before you start.", "· 2 will reach 0" or "· all in stock".
    var summary: String {
        let supplies = supplyCount == 1 ? "1 supply" : "\(supplyCount) supplies"
        let stock = if notAvailableCount > 0 {
            "\(notAvailableCount) not available"
        } else if willReachZeroCount > 0 {
            "\(willReachZeroCount) will reach 0"
        } else {
            "all in stock"
        }
        return "\(supplies) · \(stock). Add or remove items before you start."
    }

    /// "Start procedure · 10 items" (the count only); "Start procedure" until the template is in.
    var startTitle: String {
        guard state == .loaded else { return "Start procedure" }
        return "Start procedure · \(itemCount == 1 ? "1 item" : "\(itemCount) items")"
    }

    /// Start waits for the template and needs at least one supply; a short item never blocks it.
    var canStart: Bool { state == .loaded && supplyCount > 0 && !isStarting }

    /// "0 will remain" or "Not available · 2 in stock"; nil when the stock covers the row with some left.
    func warning(for supply: Supply) -> Warning? {
        guard supply.quantity > 0 else { return nil }
        let quantity = Decimal(supply.quantity)
        if quantity > supply.item.quantity {
            let stock = formatters.number(max(supply.item.quantity, 0))
            return Warning(text: "Not available · \(stock) in stock", tone: .danger)
        }
        if quantity == supply.item.quantity {
            return Warning(text: "0 will remain", tone: .warning)
        }
        return nil
    }

    /// "1 open · 1 in stock", or "Will take 1 from stock · 0 unopened left" once Take new is on.
    func line(for bottle: Bottle) -> String {
        let unopened = bottle.item.unopened
        if bottle.takesNew {
            return "Will take 1 from stock · \(formatters.number(max(unopened - 1, 0))) unopened left"
        }
        return "\(bottle.item.openCount) open · \(formatters.number(max(unopened, 0))) in stock"
    }

    /// The bottles taken new, listed with the supplies as one item each.
    var takenNew: [Bottle] { bottles.filter(\.takesNew) }

    /// "40 needles in stock" under a product in Add item; "1 unopened · 2 open" for a multi-use one, and "Out of stock"
    /// once + found nothing unopened.
    func addCaption(for product: ProductSummary) -> String? {
        if product.id == outOfStockProductID { return "Out of stock" }
        return switch product.tracking {
        case .countable: "\(formatters.quantity(product.quantity, unit: product.unit)) in stock"
        case .multiUse: "\(formatters.number(product.unopened)) unopened · \(product.openCount) open"
        }
    }

    /// "Out of stock" reads in danger; every other caption in the secondary color.
    func addCaptionTone(for product: ProductSummary) -> StatusTone? {
        product.id == outOfStockProductID ? .danger : nil
    }

    /// What Add item says with nothing to list: nothing while the products load, and how to retry when they failed.
    var addItemEmptyText: String {
        if hasLoadedProducts { return "No products match." }
        return productsFailed ? "Couldn't load products. Close and reopen Add item to try again." : ""
    }

    /// The template's multi-use products, listed under "Opened a new one?"; one Add item brought in is listed with
    /// the supplies only.
    var templateBottles: [Bottle] { bottles.filter { !$0.isAdded } }

    /// "10 items deducted" under "{name} started".
    static func itemsDeducted(_ count: Int) -> String {
        count == 1 ? "1 item deducted" : "\(count) items deducted"
    }
}
