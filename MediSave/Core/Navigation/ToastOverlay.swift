import SwiftUI

/// The dark ink card above the tab bar or the pinned bar: title, one detail line, optional Undo.
struct ToastView: View {
    let toast: Toast
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(toast.title).textStyle(.bodyStrong14).foregroundStyle(Color.ms.textOnDark)
                if let detail = toast.detail {
                    Text(detail).textStyle(.caption12).foregroundStyle(Color.ms.mute)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if toast.hasUndo {
                Button("Undo", action: onUndo)
                    .textStyle(.button14)
                    .foregroundStyle(Color.ms.textOnDark)
                    .frame(minWidth: ControlHeight.hitTarget, minHeight: ControlHeight.hitTarget)
                    .accessibilityIdentifier("toast.undo")
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .background(Color.ms.surfaceDark, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .msShadow(Shadow.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast")
    }
}

/// Places the current toast at the bottom of the app, above the tab bar (a safe-area inset) and the
/// pinned bar (reported through `ToastCenter.bottomInset`). `AppTabsView` applies it once.
struct ToastHostModifier: ViewModifier {
    @Environment(\.appDependencies) private var dependencies

    func body(content: Content) -> some View {
        let toasts = dependencies.toasts
        content.overlay(alignment: .bottom) {
            if let toast = toasts.current {
                ToastView(toast: toast) { toasts.undo() }
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, toasts.bottomInset + Spacing.md)
                    .frame(maxWidth: PageLayout.contentMaxWidth)
                    .transition(.opacity)
                    .id(toast.id)
            }
        }
        .animation(Motion.baseAnimation, value: toasts.current)
    }
}

extension View {
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}

#Preview("Toast") {
    VStack(spacing: Spacing.md) {
        ToastView(toast: Toast(title: "Adjustment saved", detail: "Septocaine 4% · 54 → 52", undo: {})) {}
        ToastView(toast: Toast(title: "Out of stock")) {}
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
