import SwiftUI

/// One line on Review invoice (f23; Appendix B `invoice.line[n]`): the raw text in monospace beside its state's badge,
/// the product or what the line needs beside the amount as read, then what the line's state shows under them
/// (`InvoiceLineDetails`). A line waiting for a choice has the ink hairline on the cream page; a resolved one is the
/// soft card. A Skipped line is muted.
struct InvoiceLineCard: View {
    @Environment(\.writeAccess) private var writeAccess
    let viewModel: InvoiceReviewViewModel
    let line: InvoiceLine

    /// `invoice.line[n]`, n counted from 1 as the invoice reads.
    private var identifier: String { "invoice.line[\(line.number)]" }

    var body: some View {
        CardView(variant: line.isResolved ? .soft : .outline) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(line.raw)
                        .textStyle(.mono)
                        .foregroundStyle(Color.ms.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("\(identifier).raw")
                    InvoiceLineBadge(
                        line: line, canReopen: viewModel.canReopen(line), identifier: "\(identifier).state",
                        onReopen: reopen
                    )
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    Text(viewModel.headline(for: line))
                        .textStyle(.bodyStrong16)
                        .foregroundStyle(line.state == .skipped ? Color.ms.textSecondary : Color.ms.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("\(identifier).headline")
                    if let amount = viewModel.amount(for: line) {
                        Text(amount)
                            .textStyle(.body14)
                            .foregroundStyle(line.state == .skipped ? Color.ms.textSecondary : Color.ms.textBody)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("\(identifier).amount")
                    }
                }
                InvoiceLineDetails(
                    viewModel: viewModel, line: line, identifier: identifier, onChoice: perform, onReopen: reopen
                )
            }
        }
    }

    /// Each choice is a write: in read-only mode the sheet says why instead (MS-142).
    private func perform(_ choice: InvoiceReviewViewModel.Choice) {
        writeAccess.perform {
            Task { await viewModel.perform(choice, on: line) }
        }
    }

    /// The badge of a resolved line, or Undo on a skipped one.
    private func reopen() {
        writeAccess.perform {
            Task { await viewModel.reopen(line) }
        }
    }
}
