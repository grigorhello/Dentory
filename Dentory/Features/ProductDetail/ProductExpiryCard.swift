import SwiftUI

/// The expiry card (f20): one row per dated batch, soonest first, the total line, the caption and Add expiry.
/// Without a dated batch the card says "No expiry dates yet." and the total line still shows the undated stock.
/// Tapping a batch opens Edit batch and Add expiry adds one (MS-119).
struct ProductExpiryCard: View {
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

/// "54 of 54 tracked · 54 expire within 90 days" with the unit on the right.
private extension ProductExpiryCard {
    var totalLine: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(viewModel.expiryTotalLine)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.sm)
            Text(viewModel.unit).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
        }
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("product.expiryTotal")
    }
}

/// "Expires · Qty · Lot" above the batch rows, in the list header's Inter 600 14 (f20).
private struct ExpiryHeaderRow: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Expires")
                Spacer()
                Text("Qty")
                Spacer()
                Text("Lot")
            }
            .textStyle(.bodyStrong14)
            .foregroundStyle(Color.ms.textSecondary)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            ListDivider()
        }
    }
}

/// Date in bold with the days-left badge under it, the quantity in Inter 700 20 as f20 draws it, the lot in mono.
private struct ProductBatchRow: View {
    let row: ProductDetailViewModel.BatchRow

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(row.dateText).textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink)
                    StatusBadge(row.daysText, tone: row.daysTone, size: .small)
                }
                Spacer(minLength: Spacing.sm)
                Text(row.quantityText).textStyle(.title20).foregroundStyle(Color.ms.ink).monospacedDigit()
                Spacer(minLength: Spacing.sm)
                Text(row.lot)
                    .textStyle(.mono)
                    .foregroundStyle(Color.ms.textSecondary)
                    .frame(minWidth: Spacing.xxxl, alignment: .trailing)
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
}
