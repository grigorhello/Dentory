import SwiftUI

/// A filter pill: ink fill when selected, cream-soft with a line border otherwise (PRD §7).
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
                Text(label).textStyle(.body14)
                if let count {
                    Text("\(count)")
                        .textStyle(.micro12)
                        .foregroundStyle(isSelected ? Color.ms.onPrimary : Color.ms.textSecondary)
                }
            }
            .foregroundStyle(isSelected ? Color.ms.onPrimary : Color.ms.ink)
            .lineLimit(1)
            .padding(.horizontal, Spacing.md + Spacing.xxs)
            .frame(height: ControlHeight.sm)
            .background(isSelected ? Color.ms.ink : Color.ms.surfaceCard, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.ms.ink : Color.ms.line, lineWidth: 1))
            .contentShape(Capsule())
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
