import SwiftUI

/// Available, Minimum and Target in three columns, then the system estimate and the last count (f20), in the frame's
/// sizes: 14 pt labels and lines, a 12 pt unit; a warning notice with the recommended addition when the product is
/// Low or Out of stock. At the accessibility text sizes the figures go one under the other, and the last count under
/// the estimate, where side by side their words would break ("Avail / able", MS-149).
struct ProductQuantityCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let viewModel: ProductDetailViewModel

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        CardView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AnyLayout.row(stacked: isStacked, alignment: .top, stackedSpacing: Spacing.md) {
                    column("Available", value: viewModel.availableText, unit: viewModel.unit)
                    column("Minimum", value: viewModel.minimumText, unit: nil)
                    column("Target", value: viewModel.targetText, unit: nil)
                }
                ListDivider()
                AnyLayout.row(stacked: isStacked, alignment: .top) {
                    Text(viewModel.estimateLine)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                    if !isStacked {
                        Spacer(minLength: Spacing.sm)
                    }
                    Text(viewModel.countedLine)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.textBody)
                        .multilineTextAlignment(isStacked ? .leading : .trailing)
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
            Text(label).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
            Text(value).textStyle(.display32).foregroundStyle(Color.ms.ink).monospacedDigit()
            if let unit {
                Text(unit).textStyle(.micro12).foregroundStyle(Color.ms.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
