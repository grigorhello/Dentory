import Foundation

/// What Receive manually says (f24, PRD §6.5, Appendix B `manual`, Appendix C `pickProduct`): the field labels in the
/// unit the product is received in, the product's stock line, the line under the quantity with the conversion and its
/// effect, what Choose product says when its list is empty, and the toast. The state and the intents are in
/// `ManualReceiveViewModel.swift`.
extension ManualReceiveViewModel {
    static let productPlaceholder = "Choose a product"

    /// "Quantity" until a product is chosen, then in the unit it is received in: "Quantity (boxes)" for a product
    /// received in packs, "Quantity (kits)" for one received by the unit.
    var quantityLabel: String {
        guard let product else { return "Quantity" }
        return "Quantity (\(Self.receivedUnits(of: product)))"
    }

    /// "Cost per unit" until a product is chosen, then per the unit it is received in: "Cost per box", "Cost per kit".
    var costLabel: String {
        guard let product else { return "Cost per unit" }
        return "Cost per \(ClinicFormatters.singular(of: Self.receivedUnits(of: product)))"
    }

    /// The clinic's currency, before the cost ("$").
    var currencySymbol: String { formatters.currencySymbol }

    /// Under the chosen product and on each row of Choose product: "Anesthetic · 54 cartridges in stock", or the
    /// unopened and open ones of a multi-use product, "Endodontics · 0 unopened · 1 open".
    func stockLine(for product: ReceivableProduct) -> String {
        let stock = switch product.tracking {
        case .countable: "\(formatters.quantity(product.quantity, unit: product.unit)) in stock"
        case .multiUse: "\(formatters.number(product.unopened)) unopened\(Caption.separator)\(product.openCount) open"
        }
        return Caption.joined(product.categoryName, stock)
    }

    /// What the quantity does (f24, PRD §6.5): "Current 1 → after 5 kits"; with a pack, the conversion first,
    /// "5 boxes = 250 cartridges · Current 54 → after 304"; for a multi-use product the unopened ones, which is what a
    /// delivery adds to, "Current 0 → after 4 unopened kits". Before a quantity, the pack alone ("1 box = 50
    /// cartridges"), or nothing for a product received by the unit.
    var effectLine: String? {
        guard let product else { return nil }
        guard let quantity, quantity > 0 else {
            return product.pack == nil ? nil : conversion(of: 1, for: product)
        }
        let after = product.currentStock + product.countedQuantity(received: quantity)
        let afterText: String = switch (product.pack == nil, product.tracking) {
        case (true, .countable): formatters.quantity(after, unit: product.unit)
        case (true, .multiUse): "\(formatters.number(after)) unopened \(after == 1 ? unitWord(product) : product.unit)"
        case (false, .countable): formatters.number(after)
        case (false, .multiUse): "\(formatters.number(after)) unopened"
        }
        let change = "Current \(formatters.number(product.currentStock)) → after \(afterText)"
        guard product.pack != nil else { return change }
        return "\(conversion(of: quantity, for: product))\(Caption.separator)\(change)"
    }

    /// What Choose product says over an empty list: nothing matches the search, the clinic has no products yet, or they
    /// did not load (nothing while they load).
    var pickEmptyText: String {
        switch state {
        case .loaded: products.isEmpty ? "No products yet." : "No products match."
        case .failed: "Couldn't load products. Reopen Choose product to try again."
        case .loading: ""
        }
    }

    /// "Received · Septocaine 4% 1:100,000 +250 cartridges": in counted units, without Undo (PRD §7).
    func receivedMessage(product: ReceivableProduct, quantity: Decimal) -> Message {
        Message(title: "Received", detail: "\(product.name) +\(formatters.quantity(quantity, unit: product.unit))")
    }

    /// The unit a delivery is counted in, in the plural: the pack's ("boxes") or the product's own ("kits").
    private static func receivedUnits(of product: ReceivableProduct) -> String {
        product.pack.map { ClinicFormatters.plural(of: $0.unit) } ?? product.unit
    }

    /// "5 boxes = 250 cartridges", "1 box = 50 cartridges".
    private func conversion(of quantity: Decimal, for product: ReceivableProduct) -> String {
        let packs = formatters.quantity(quantity, unit: Self.receivedUnits(of: product))
        return "\(packs) = \(formatters.quantity(product.countedQuantity(received: quantity), unit: product.unit))"
    }

    private func unitWord(_ product: ReceivableProduct) -> String {
        ClinicFormatters.singular(of: product.unit)
    }
}
