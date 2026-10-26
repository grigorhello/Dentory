import Foundation

/// What a line's badge on Review invoice does (Appendix B `invoice.line[n].state`; MS-130 and the decision on #101):
/// a line the admin settled reopens in the state it was read in, as does a line read as Matched whose product the
/// admin changed, which goes back to the product it was read as; a line read as Matched and still on that product, and
/// a Possible match whose suggestion is wrong, open Which product is this? to be pointed at another product. Nothing
/// once the invoice is received (MS-131). The reopening itself is in `InvoiceReviewViewModel.swift`.
extension InvoiceReviewViewModel {
    func badgeAction(for line: InvoiceLine) -> BadgeAction? {
        guard !isReceived else { return nil }
        if line.canReopen { return .reopen }
        return line.canPickAnother ? .pickAnother : nil
    }

    /// A tap on a line's badge; Which product is this? waits while the line's choice is saved.
    func tapBadge(on line: InvoiceLine) async {
        switch badgeAction(for: line) {
        case .reopen: await reopen(line)
        case .pickAnother where !isSaving(line): sheet = .match(line)
        case .pickAnother, nil: break
        }
    }
}
