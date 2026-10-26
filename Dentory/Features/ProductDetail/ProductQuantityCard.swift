import SwiftUI

/// Available, Minimum and Target in three columns, then the system estimate and the last count (f20);
/// a warning notice with the recommended addition when the product is Low or Out of stock.
struct ProductQuantityCard: View {
    let viewModel: ProductDetailViewModel

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    column("Available", value: viewModel.availableText, unit: viewModel.unit)
                    column("Minimum", value: viewModel.minimumText, unit: nil)
                    column("Target", value: viewModel.targetText, unit: nil)
                }
                ListDivider()
                HStack(alignment: .top, spacing: Spacing.md) {
                    Text(viewModel.estimateLine)
                        .textStyle(.body16)
                        .foregroundStyle(Color.ms.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Spacing.sm)
                    Text(viewModel.countedLine)
                        .textStyle(.body16)
                        .foregroundStyle(Color.ms.textBody)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let recommendation = viewModel.recommendationLine {
                    Notice(recommendation, tone: .warning)
                        .accessibilityIdentifier("product.recommendation")
                }
            }
        }
        .accessibilityIdentifier("product.quantity")
    }

    private func column(_ label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).textStyle(.body16).foregroundStyle(Color.ms.textSecondary)
            Text(value).textStyle(.display32).foregroundStyle(Color.ms.ink).monospacedDigit()
            if let unit {
                Text(unit).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
