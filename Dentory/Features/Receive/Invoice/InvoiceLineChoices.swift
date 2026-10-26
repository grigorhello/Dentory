import SwiftUI

/// The two buttons of a line waiting for a choice, side by side (`invoice.line[n].a` and `.b`), stacked when a label
/// does not fit its half; they wait while the line's choice is saved.
struct InvoiceLineChoices: View {
    let first: InvoiceReviewViewModel.Choice
    let second: InvoiceReviewViewModel.Choice
    let identifier: String
    let isSaving: Bool
    let perform: (InvoiceReviewViewModel.Choice) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            EqualWidthHStack(spacing: Spacing.sm) { buttons }
            VStack(spacing: Spacing.sm) { buttons }
        }
    }

    @ViewBuilder private var buttons: some View {
        button(first, id: "a")
        button(second, id: "b")
    }

    private func button(_ choice: InvoiceReviewViewModel.Choice, id: String) -> some View {
        MSButton(
            InvoiceReviewViewModel.title(of: choice),
            variant: InvoiceReviewViewModel.isPrimary(choice) ? .primary : .tertiary, size: .small,
            isFullWidth: true, isDisabled: isSaving
        ) {
            perform(choice)
        }
        .accessibilityIdentifier("\(identifier).\(id)")
    }
}
