import SwiftUI

/// A filter chip as f9 and f16 draw it: a 6 pt rounded rectangle without a border, Inter 600 14, ink fill when
/// selected and cream-soft otherwise.
struct FilterChip: View {
    let label: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    init(_ label: String, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs + Spacing.xxs) {
                Text(label).textStyle(.bodyStrong14)
                if let count {
                    Text("\(count)")
                        .textStyle(.micro12)
                        .foregroundStyle(isSelected ? Color.ms.onPrimary : Color.ms.textSecondary)
                }
            }
            .foregroundStyle(isSelected ? Color.ms.onPrimary : Color.ms.ink)
            .lineLimit(1)
            .padding(.horizontal, Spacing.md)
            // 36 pt, taller only when the accessibility text sizes need it, rather than cut the label (MS-149).
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: ControlHeight.sm)
            .background(
                isSelected ? Color.ms.ink : Color.ms.surfaceCard,
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .frame(minHeight: ControlHeight.hitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(Motion.fastAnimation, value: isSelected)
    }
}

#Preview("Chips") {
    HStack(spacing: Spacing.sm) {
        FilterChip("All", isSelected: true) {}
        FilterChip("Low", count: 3, isSelected: false) {}
        FilterChip("Expiring", isSelected: false) {}
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
