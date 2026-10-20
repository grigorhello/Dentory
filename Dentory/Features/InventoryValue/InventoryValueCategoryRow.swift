import SwiftUI

/// One category of By category (f10): name, value and share of the total on one line, a thin bar of the share
/// under them.
struct InventoryValueCategoryRow: View {
    let name: String
    let value: String
    let shareText: String
    /// From 0 to 1.
    let share: Double
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Text(name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ListRowValue(value)
                    Text(shareText)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.textSecondary)
                        .monospacedDigit()
                        .frame(minWidth: ControlHeight.sm, alignment: .trailing)
                }
                ShareBar(share: share)
            }
            .padding(.vertical, Spacing.md)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(value), \(shareText) of the total")
    }
}

/// The 4 pt bar under a category: the share in ink over the line color, the track's rounded ends clipping both.
private struct ShareBar: View {
    let share: Double

    var body: some View {
        Rectangle()
            .fill(Color.ms.line)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.ms.ink)
                    .scaleEffect(x: share, anchor: .leading)
            }
            .frame(height: Spacing.xs)
            .clipShape(Capsule())
    }
}

#Preview("Category rows") {
    ListCard {
        InventoryValueCategoryRow(name: "Anesthetic", value: "$4,860", shareText: "39%", share: 0.39)
        InventoryValueCategoryRow(name: "Restorative", value: "$2,410", shareText: "19%", share: 0.19)
        InventoryValueCategoryRow(name: "Other", value: "$600", shareText: "5%", share: 0.05, showsDivider: false)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
