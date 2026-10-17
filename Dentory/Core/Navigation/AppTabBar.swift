import SwiftUI

/// The bottom tab bar of f25, drawn once for iPhone and iPad (iOS 18 would otherwise float the iPad
/// tabs at the top): Lucide icons, active tab in primary blue, red count badge on To buy.
struct AppTabBar: View {
    let selected: AppTab
    let toBuyCount: Int
    let select: (AppTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.ms.line).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    AppTabBarItem(
                        tab: tab,
                        isSelected: tab == selected,
                        badge: tab == .toBuy ? toBuyCount : 0
                    ) {
                        select(tab)
                    }
                }
            }
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .frame(maxWidth: PageLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.ms.surfacePage)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabBar")
    }
}

private struct AppTabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                IconView(tab.icon, size: 24)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            TabBadge(count: badge)
                                .offset(x: Spacing.sm + Spacing.xxs, y: -Spacing.sm)
                        }
                    }
                Text(tab.title).textStyle(.micro12)
            }
            .foregroundStyle(isSelected ? Color.ms.primary : Color.ms.textSecondary)
            .frame(maxWidth: .infinity, minHeight: ControlHeight.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Motion.fastAnimation, value: isSelected)
        .accessibilityLabel(tab.title)
        .accessibilityValue(badge > 0 ? "\(badge)" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }
}

/// The red count on the To buy tab; hidden at 0 by the caller.
private struct TabBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .textStyle(.micro12)
            .foregroundStyle(Color.ms.onPrimary)
            .padding(.horizontal, Spacing.xs + Spacing.xxs)
            .frame(minWidth: Spacing.lg + Spacing.xxs, minHeight: Spacing.lg + Spacing.xxs)
            .background(Color.ms.danger, in: Capsule())
            .accessibilityHidden(true)
    }
}

#Preview("Tab bar") {
    VStack {
        Spacer()
        AppTabBar(selected: .home, toBuyCount: 3) { _ in }
    }
    .background(Color.ms.canvas)
}
