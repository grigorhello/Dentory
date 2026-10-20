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
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(viewModel.headline.value)
                            .textStyle(.display32)
                            .foregroundStyle(Color.ms.textOnDark)
                        if let suffix = viewModel.headline.suffix {
                            Text(suffix).textStyle(.body14).foregroundStyle(Color.ms.mute)
                        }
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

    /// "After trial", then "$99" struck through, "$49.50 / month" and "50% off for life" with the promotion. With large
    /// text they stack under the label.
    private var afterTrial: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.ms.inkMid).frame(height: 1)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Spacing.sm + Spacing.xxs) {
                    afterTrialLabel
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm + Spacing.xxs) { price }
                        .fixedSize()
                    promoBadge.fixedSize()
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    afterTrialLabel
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) { price }
                    promoBadge
                }
            }
            .padding(.top, Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("billing.price")
        }
        .padding(.top, Spacing.lg - Spacing.xxs)
    }

    private var afterTrialLabel: some View {
        Text("After trial").textStyle(.body14).foregroundStyle(Color.ms.mute)
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
