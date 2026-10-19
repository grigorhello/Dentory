import SwiftUI

/// One line still to buy (f25 Admin, f26 Staff): the admin's checkbox, the name over "Current 1 · target 5 ·
/// Patterson", and −/+ around the quantity to buy, never under 1. Swipe left to remove it.
struct ToBuyRow: View {
    let item: ToBuyItem
    let line: String
    let isAdmin: Bool
    @Binding var isSelected: Bool
    @Binding var quantity: Int
    let onRemove: () -> Void

    private var identifier: String { "order.row[\(item.id.uuidString.lowercased())]" }

    var body: some View {
        SwipeActionRow(actionTitle: "Remove", actionIdentifier: "\(identifier).remove", action: onRemove) {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.md) {
                    if isAdmin {
                        checkbox
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(item.name)
                            .textStyle(.body16)
                            .foregroundStyle(Color.ms.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(line)
                            .textStyle(.caption12)
                            .foregroundStyle(Color.ms.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    QuantityStepper(value: $quantity, minimum: 1, identifier: identifier)
                }
                .padding(.vertical, Spacing.md)
                ListDivider()
            }
            .background(Color.ms.surfaceCard)
        }
    }

    /// The 24 pt box lines up with the card's edge as f25 draws it; its 44 pt target reaches into the padding.
    private var checkbox: some View {
        Button {
            isSelected.toggle()
        } label: {
            CheckboxBox(isOn: isSelected)
                .frame(width: ControlHeight.hitTarget, height: ControlHeight.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -(ControlHeight.hitTarget - CheckboxBox.size) / 2)
        .accessibilityLabel("Select \(item.name)")
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isSelected ? "Checked" : "Unchecked")
        .accessibilityIdentifier("\(identifier).select")
    }
}
