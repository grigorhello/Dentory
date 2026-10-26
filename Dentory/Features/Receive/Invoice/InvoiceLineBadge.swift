import SwiftUI

/// A line's state as a small badge (Appendix B `invoice.line[n].state`). On a line the admin resolved it is a button
/// that reopens the line in the state it was read in, until the invoice is received (MS-131); its target reaches 44 pt
/// without growing the row.
struct InvoiceLineBadge: View {
    let line: InvoiceLine
    let canReopen: Bool
    let identifier: String
    let onReopen: () -> Void

    var body: some View {
        if canReopen {
            Button(action: onReopen) {
                badge
                    .padding(.vertical, Spacing.md)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -Spacing.md)
            .accessibilityLabel(kind.rawValue)
            .accessibilityHint("Reopens the line")
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
