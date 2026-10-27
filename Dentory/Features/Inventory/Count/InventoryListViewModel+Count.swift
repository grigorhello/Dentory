import Foundation

/// What count mode shows (f18, Appendix C `reviewCount` and `cancelCount`): the rows' values and sub-lines,
/// the review button, the review rows and the discard question. The state and the intents are in
/// `InventoryListViewModel.swift`.
extension InventoryListViewModel {
    /// "Count" while counting (f18), else "Inventory".
    var title: String { isCounting ? "Count" : "Inventory" }

    /// The stepper's value: the count once touched, else the estimate.
    func countValue(for product: ProductSummary) -> Int {
        count?.value(for: product) ?? 0
    }

    /// The row's stepper binding: `$viewModel[countOf: product]` reads the value and writes through `setCount`.
    subscript(countOf product: ProductSummary) -> Int {
        get { countValue(for: product) }
        set { setCount(newValue, for: product) }
    }

    /// True when the row's count differs from the estimate: its value turns blue.
    func isCorrected(_ product: ProductSummary) -> Bool {
        count?.isCorrection(product) ?? false
    }

    /// "est. 54 cartridges · Operatory 1 · Drawer A", or "Count unopened only · Lab · Shelf 1" for a multi-use
    /// product, whose open bottles are not counted.
    func countLine(for product: ProductSummary) -> String {
        let figures = switch product.tracking {
        case .countable: "est. \(formatters.quantity(StockCount.estimate(of: product), unit: product.unit))"
        case .multiUse: "Count unopened only"
        }
        return Caption.joined(figures, product.location)
    }

    /// "Review · 2 corrections", or "Review count" (disabled) until a quantity changed (f18).
    var reviewTitle: String {
        correctionCount == 0 ? "Review count" : "Review · \(Self.corrections(correctionCount))"
    }

    /// "Apply count · 2 corrections"; disabled once every row was undone.
    var applyTitle: String {
        "Apply count · \(Self.corrections(correctionCount))"
    }

    /// "43 → 41", or "1 → 2 unopened" for a multi-use product.
    func correctionLine(for product: ProductSummary) -> String {
        let estimate = formatters.number(StockCount.estimate(of: product))
        let counted = formatters.number(Decimal(countValue(for: product)))
        let line = "\(estimate) → \(counted)"
        return product.tracking == .multiUse ? "\(line) unopened" : line
    }

    /// Up in success, down in danger.
    func correctionTone(for product: ProductSummary) -> StatusTone {
        Decimal(countValue(for: product)) > StockCount.estimate(of: product) ? .success : .danger
    }

    /// "2 changes. Inventory stays as it is."
    var discardMessage: String {
        let changes = correctionCount == 1 ? "1 change" : "\(correctionCount) changes"
        return "\(changes). Inventory stays as it is."
    }

    static func corrections(_ count: Int) -> String {
        count == 1 ? "1 correction" : "\(count) corrections"
    }

    /// "3 products updated" under "Count applied".
    static func productsUpdated(_ count: Int) -> String {
        count == 1 ? "1 product updated" : "\(count) products updated"
    }
}
