import SwiftUI

/// The expiry card (f20): one row per dated batch, soonest first, the total line, the caption and Add expiry.
/// Without a dated batch the card says "No expiry dates yet." and the total line still shows the undated stock.
/// Tapping a batch opens Edit batch and Add expiry adds one (MS-119).
struct ProductExpiryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let viewModel: ProductDetailViewModel
    let onBatch: (UUID) -> Void
    let onAddExpiry: () -> Void

    var body: some View {
        Eyebrow("Expiry")
            .accessibilityAddTraits(.isHeader)
        if viewModel.batchRows.isEmpty {
            EmptyStateView("No expiry dates yet.")
                .accessibilityIdentifier("product.expiryEmpty")
            totalLine
        } else {
            ListCard {
                ExpiryHeaderRow()
                ForEach(viewModel.batchRows) { row in
                    Button {
                        onBatch(row.id)
                    } label: {
                        ProductBatchRow(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("product.batch[\(row.id.uuidString.lowercased())]")
                }
                totalLine
            }
            Text("Tap a batch to edit its expiry, lot or quantity.")
                .textStyle(.micro12)
                .foregroundStyle(Color.ms.textSecondary)
        }
        Button(action: onAddExpiry) {
            HStack(spacing: Spacing.sm) {
                IconView(.plus, size: 16)
                Text("Add expiry")
            }
        }
        .buttonStyle(.ms(.text, size: .medium))
        .accessibilityIdentifier("product.addExpiry")
    }
}

/// "54 of 54 tracked · 54 expire within 90 days" with the unit on the right, or under it at the accessibility text
/// sizes, where beside it the unit breaks mid-word ("cartri / dges", MS-149).
private extension ProductExpiryCard {
    var totalLine: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = AnyLayout.row(stacked: isStacked, alignment: .top, stackedSpacing: Spacing.xxs)
        return layout {
            Text(viewModel.expiryTotalLine)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textBody)
                .fixedSize(horizontal: false, vertical: true)
            if !isStacked {
                Spacer(minLength: Spacing.sm)
            }
            Text(viewModel.unit).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
        }
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("product.expiryTotal")
    }
}

/// "Expires · Qty · Lot" above the batch rows, in the list header's Inter 600 14 (f20); at the accessibility text
/// sizes Qty and Lot go under Expires, as each row's quantity and lot go under its date.
private struct ExpiryHeaderRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Expires")
                        HStack {
                            Text("Qty")
                            Spacer()
                            Text("Lot")
                        }
                    }
                } else {
                    HStack {
                        Text("Expires")
                        Spacer()
                        Text("Qty")
                        Spacer()
                        Text("Lot")
                    }
                }
            }
            .textStyle(.bodyStrong14)
            .foregroundStyle(Color.ms.textSecondary)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            ListDivider()
        }
    }
}

/// Date in bold with the days-left badge under it, the quantity in Inter 700 20 as f20 draws it, the lot in mono. At
/// the accessibility text sizes the quantity and lot go under the badge: beside the badge, which keeps its width, the
/// date and lot broke mid-word and the row ran past the screen's edge (MS-149).
private struct ProductBatchRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let row: ProductDetailViewModel.BatchRow

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        dateAndDays
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            quantity
                            Spacer(minLength: Spacing.sm)
                            lot
                        }
                    }
                } else {
                    HStack(alignment: .center, spacing: Spacing.md) {
                        dateAndDays
                        Spacer(minLength: Spacing.sm)
                        quantity
                        Spacer(minLength: Spacing.sm)
                        lot
                    }
                }
            }
            .padding(.vertical, Spacing.md)
            // The soonest batch due within the window stands out with the ink hairline (MS-119).
            .padding(.horizontal, row.isEmphasized ? Spacing.sm : 0)
            .msHairline(row.isEmphasized ? Color.ms.ink : .clear, cornerRadius: Radius.sm)
            .padding(.vertical, row.isEmphasized ? Spacing.xs : 0)
            ListDivider()
        }
        .contentShape(Rectangle())
    }

    private var dateAndDays: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(row.dateText).textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink)
            StatusBadge(row.daysText, tone: row.daysTone, size: .small)
        }
    }

    private var quantity: some View {
        Text(row.quantityText).textStyle(.title20).foregroundStyle(Color.ms.ink).monospacedDigit()
    }

    private var lot: some View {
        Text(row.lot)
            .textStyle(.mono)
            .foregroundStyle(Color.ms.textSecondary)
            .frame(minWidth: Spacing.xxxl, alignment: .trailing)
    }
}
