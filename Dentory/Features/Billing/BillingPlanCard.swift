import SwiftUI

/// The dark card of f34: the free trial with its end, or the plan with its next payment, and the price after the trial
/// with the lifetime promotion struck through beside it.
struct BillingPlanCard: View {
    let viewModel: BillingViewModel

    var body: some View {
        CardView(variant: .dark, padding: Spacing.lg + Spacing.xs) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(viewModel.eyebrow, color: .ms.mute)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) { headline }
                        VStack(alignment: .leading, spacing: Spacing.xxs) { headline }
                    }
                    .padding(.top, Spacing.sm + Spacing.xxs)
                    if let line = viewModel.dateLine {
                        Text(line)
                            .textStyle(.body14)
                            .foregroundStyle(Color.ms.mute)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Spacing.xs + Spacing.xxs)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("billing.trial")
                if viewModel.showsAfterTrialPrice {
                    afterTrial
                } else if viewModel.isPromo {
                    StatusBadge(BillingViewModel.promoBadge, tone: .success, size: .small)
                        .padding(.top, Spacing.md)
                        .accessibilityIdentifier("billing.price")
                }
            }
        }
    }

    /// "3 months" and "free" on one line, or the word under the figure where they do not fit.
    @ViewBuilder private var headline: some View {
        Text(viewModel.headline.value)
            .textStyle(.display32)
            .foregroundStyle(Color.ms.textOnDark)
        if let suffix = viewModel.headline.suffix {
            Text(suffix).textStyle(.body14).foregroundStyle(Color.ms.mute)
        }
    }

    /// "After trial", then "$99" struck through, "$49.50 / month" and "50% off for life" with the promotion: in one row
    /// where it fits, with the label on two lines as f34 draws it on the iPhone 16, else stacked under the label: the
    /// price beside its badge, the badge under the price, then each on its own line. No word is ever split.
    private var afterTrial: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.ms.inkMid).frame(height: 1)
            ViewThatFits(in: .horizontal) {
                priceRow(label: "After trial")
                priceRow(label: "After\ntrial")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    afterTrialLabel("After trial")
                    HStack(alignment: .center, spacing: Spacing.sm + Spacing.xxs) {
                        priceLine
                        promoBadge
                    }
                    .fixedSize()
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    afterTrialLabel("After trial")
                    priceLine.fixedSize()
                    promoBadge.fixedSize()
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    afterTrialLabel("After trial")
                    price
                    promoBadge
                }
            }
            .padding(.top, Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("billing.price")
        }
        .padding(.top, Spacing.lg - Spacing.xxs)
    }

    /// The label on the left, the price and the badge on the right, all at their natural width. The label's frame
    /// takes the room left, rather than a spacer, which would add a gap to the width the row needs.
    private func priceRow(label: String) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm + Spacing.xxs) {
            afterTrialLabel(label)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
            priceLine.fixedSize()
            promoBadge.fixedSize()
        }
    }

    private func afterTrialLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(.body14)
            .foregroundStyle(Color.ms.mute)
            .accessibilityLabel("After trial")
    }

    private var priceLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm + Spacing.xxs) { price }
    }

    @ViewBuilder private var price: some View {
        if viewModel.isPromo {
            Text(viewModel.regularPriceText)
                .strikethrough()
                .textStyle(.body14)
                .foregroundStyle(Color.ms.mute)
                .accessibilityLabel("was \(viewModel.regularPriceText)")
        }
        Text(viewModel.monthlyPriceText)
            .textStyle(.bodyStrong16)
            .foregroundStyle(Color.ms.textOnDark)
    }

    @ViewBuilder private var promoBadge: some View {
        if viewModel.isPromo {
            StatusBadge(BillingViewModel.promoBadge, tone: .success, size: .small)
        }
    }
}
