import SwiftUI

/// The bottles card of a multi-use product (PRD §6.4, MS-120): unopened and open counts, one row per open
/// bottle with Finished, and Open a new bottle (disabled when nothing is unopened: a stock rule, not a role rule).
struct ProductBottlesCard: View {
    let viewModel: ProductDetailViewModel
    let onFinished: (UUID) -> Void
    let onOpenNew: () -> Void

    var body: some View {
        Eyebrow("Bottles")
        ListCard {
            Text(viewModel.bottlesLine)
                .textStyle(.bodyStrong16)
                .foregroundStyle(Color.ms.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)
                .accessibilityIdentifier("product.bottles")
            ListDivider()
            ForEach(viewModel.bottleRows) { row in
                ListRow(row.title, caption: row.subtitle) {
                    Button("Finished") { onFinished(row.id) }
                        .buttonStyle(.ms(.text, size: .small))
                        .disabled(viewModel.isBottleBusy)
                        .accessibilityIdentifier("product.bottle[\(row.id.uuidString.lowercased())].finished")
                }
            }
            MSButton(
                viewModel.openNewBottleTitle, variant: .tertiary, isFullWidth: true,
                isLoading: viewModel.isBottleBusy, isDisabled: !viewModel.canOpenNewBottle, action: onOpenNew
            )
            .padding(.vertical, Spacing.md)
            .accessibilityIdentifier("product.openNewBottle")
        }
    }
}
