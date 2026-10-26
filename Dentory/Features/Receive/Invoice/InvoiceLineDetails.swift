import SwiftUI

/// What a line shows under its headline: the question and the two choices of a line waiting for one, the Expiry and
/// Lot of a Matched or Created line, or Undo on a Skipped one. Once the invoice is received (MS-131), the lot and
/// expiry it came in with, as text, and nothing to undo.
struct InvoiceLineDetails: View {
    let viewModel: InvoiceReviewViewModel
    let line: InvoiceLine
    let identifier: String
    let onChoice: (InvoiceReviewViewModel.Choice) -> Void
    let onReopen: () -> Void

    var body: some View {
        if let question = viewModel.question(for: line), let choices = viewModel.choices(for: line) {
            Text(question)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textBody)
                .padding(.top, Spacing.xxs)
                .accessibilityIdentifier("\(identifier).question")
            InvoiceLineChoices(
                first: choices.first, second: choices.second, identifier: identifier,
                isSaving: viewModel.isSaving(line), perform: onChoice
            )
            .padding(.top, Spacing.xxs)
        } else if line.increasesInventory, viewModel.isReceived {
            InvoiceLineReceivedBatch(text: viewModel.receivedBatch(for: line), identifier: identifier)
        } else if line.increasesInventory {
            InvoiceLineBatchRow(viewModel: viewModel, line: line, identifier: identifier)
        } else if line.state == .skipped, !viewModel.isReceived {
            MSButton(
                InvoiceReviewViewModel.undoTitle, variant: .text, size: .small, isDisabled: viewModel.isSaving(line),
                action: onReopen
            )
            // The label lines up with the text above; the button's own inset reaches into the card's.
            .padding(.leading, -MSButtonSize.small.horizontalPadding)
            .accessibilityIdentifier("\(identifier).undo")
        }
    }
}
