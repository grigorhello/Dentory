import SwiftUI

/// The bottom tab bar of f25, drawn once for iPhone and iPad (iOS 18 would otherwise float the iPad
/// tabs at the top): Lucide icons on the cream-soft bar, the active tab in primary blue and the others in body text, as
/// the frames draw them (above PRD §7's 4.5:1 contrast), red count badge on To buy. The tabs share the bar 4 pt apart
/// inside 8 pt sides, each at most 120 pt wide, so on an iPad they cluster in the middle as f36 to f38 draw them.
struct AppTabBar: View {
    let selected: AppTab
    let toBuyCount: Int
    let select: (AppTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.ms.line).frame(height: 1)
            HStack(spacing: Spacing.xs) {
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
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .frame(maxWidth: .infinity)
        }
        .background(Color.ms.surfaceCard)
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
                // One line, shrinking a little rather than running into the next tab at the largest text sizes.
                Text(tab.title)
                    .textStyle(.micro12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Color.ms.primary : Color.ms.textBody)
            .frame(maxWidth: ControlWidth.tabItem, minHeight: ControlHeight.lg)
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
