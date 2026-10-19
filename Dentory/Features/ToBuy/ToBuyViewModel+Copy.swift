import Foundation

/// What To buy says (f25, f26, Appendix B `order`): the segments, each row's line, the selection bar, the pinned
/// button and Add item's captions. The state and the intents are in `ToBuyViewModel.swift`.
extension ToBuyViewModel {
    static let emptyText = "Nothing here yet."

    /// "To buy · 3", "Ordered · 5", "Received · 1".
    var segmentOptions: [SegmentOption<Segment>] {
        [
            SegmentOption(.toBuy, label: "To buy", count: toBuy.count),
            SegmentOption(.ordered, label: "Ordered", count: ordered.count),
            SegmentOption(.received, label: "Received", count: received.count)
        ]
    }

    /// The lines of the segment on screen.
    var rows: [ToBuyItem] {
        switch segment {
        case .toBuy: toBuy
        case .ordered: ordered
        case .received: received
        }
    }

    /// "Current 1 · target 5 · Patterson" (the supplier only when known), "4 ordered Oct 1 · Patterson",
    /// "Received Sep 26 · Patterson".
    func line(for item: ToBuyItem) -> String {
        let main = switch item.status {
        case .toBuy:
            "Current \(formatters.number(item.quantity)) · target \(formatters.number(item.target))"
        case .ordered:
            "\(formatters.number(item.buyQuantity)) ordered \(item.orderedAt.map(formatters.monthDay) ?? "")"
        case .received:
            "Received \(item.receivedAt.map(formatters.monthDay) ?? "")"
        }
        guard let supplier = item.supplier, !supplier.isEmpty else { return main }
        return "\(main) · \(supplier)"
    }

    /// "3 of 3 selected".
    var selectionSummary: String { "\(selectedItems.count) of \(toBuy.count) selected" }

    var selectionAction: String { selectedItems.isEmpty ? "Select all" : "Clear" }

    /// "Mark 3 as ordered".
    var markOrderedTitle: String { "Mark \(selectedItems.count) as ordered" }

    /// The pinned Mark N as ordered: the admin's, on the To buy segment, and disabled rather than hidden while
    /// nothing is selected, even with no lines (PRD §6.6, §7).
    var showsMarkOrdered: Bool { isAdmin && segment == .toBuy }

    /// The selection bar above the lines: the admin's, on a To buy segment with lines.
    var showsSelection: Bool { showsMarkOrdered && !toBuy.isEmpty }

    /// "Added to To buy · Gauze · suggested 2 packs" with Undo; "Already on To buy · Gauze · 2 packs" without, for a
    /// product whose line was already there.
    func addedMessage(_ added: AddedToBuy, product: ProductSummary) -> Message {
        let quantity = formatters.quantity(added.qty, unit: product.unit)
        guard added.created else {
            return Message(title: "Already on To buy", detail: "\(product.name) · \(quantity)", undoItemID: nil)
        }
        return Message(
            title: "Added to To buy", detail: "\(product.name) · suggested \(quantity)", undoItemID: added.id
        )
    }

    /// "54 cartridges in stock" under a product in Add item; "1 unopened · 2 open" for a multi-use one.
    func addCaption(for product: ProductSummary) -> String {
        switch product.tracking {
        case .countable: "\(formatters.quantity(product.quantity, unit: product.unit)) in stock"
        case .multiUse: "\(formatters.number(product.unopened)) unopened · \(product.openCount) open"
        }
    }

    /// What Add item says with nothing to list: nothing while the products load, and how to retry when they failed.
    var addItemEmptyText: String {
        if hasLoadedProducts { return "No products match." }
        return productsFailed ? "Couldn't load products. Close and reopen Add item to try again." : ""
    }

    /// "3 items", "1 item".
    static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }
}
