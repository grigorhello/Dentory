import SwiftUI

/// A line's state as a small badge (Appendix B `invoice.line[n].state`). Until the invoice is received (MS-131) it is a
/// button wherever it does something: on a line the admin settled, or whose product the admin changed, it reopens the
/// line as it was read; on a line read as Matched and still on that product, and on a Possible match, it opens Which
/// product is this? (`InvoiceReviewViewModel+Badge.swift`). Its target reaches 44 pt without growing the row.
struct InvoiceLineBadge: View {
    let line: InvoiceLine
    let action: InvoiceReviewViewModel.BadgeAction?
    let identifier: String
    let onTap: () -> Void

    var body: some View {
        if let action {
            Button(action: onTap) {
                badge
                    .padding(.vertical, Spacing.md)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -Spacing.md)
            .accessibilityLabel(kind.rawValue)
            .accessibilityHint(InvoiceReviewViewModel.badgeHint(action))
            .accessibilityIdentifier(identifier)
        } else {
            badge.accessibilityIdentifier(identifier)
        }
    }

    private var badge: some View {
        StatusBadge(kind, size: .small)
    }

    /// PRD §7's invoice line words, in the design system's tones.
    private var kind: StatusBadgeKind {
        switch line.state {
        case .matched: .matched
        case .possibleMatch: .possibleMatch
        case .newProduct: .newProduct
        case .needsReview: .needsReview
        case .created: .created
        case .skipped: .skipped
        }
    }
}
