import SwiftUI

/// The expiry card (f20): one row per dated batch, soonest first, the total line, the caption and Add expiry.
/// Tapping a batch and Add expiry open MS-119's sheets.
struct ProductExpiryCard: View {
    let viewModel: ProductDetailViewModel
    let onBatch: (UUID) -> Void
    let onAddExpiry: () -> Void

    var body: some View {
        Eyebrow("Expiry")
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
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(viewModel.expiryTotalLine)
                    .textStyle(.body16)
                    .foregroundStyle(Color.ms.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                Text(viewModel.unit).textStyle(.body16).foregroundStyle(Color.ms.textSecondary)
            }
            .padding(.vertical, Spacing.md)
            .accessibilityIdentifier("product.expiryTotal")
        }
        Text("Tap a batch to edit its expiry, lot or quantity.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
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

/// "Expires · Qty · Lot" above the batch rows.
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
            .textStyle(.body16)
            .foregroundStyle(Color.ms.textSecondary)
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}

/// Date in bold with the days-left badge under it, the quantity, the lot in mono.
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
                Text(row.quantityText).textStyle(.title24).foregroundStyle(Color.ms.ink).monospacedDigit()
                Spacer(minLength: Spacing.sm)
                Text(row.lot)
                    .textStyle(.mono)
                    .foregroundStyle(Color.ms.textSecondary)
                    .frame(minWidth: Spacing.xxxl, alignment: .trailing)
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
        .contentShape(Rectangle())
    }
}
