import SwiftUI

/// Root screen header (f6, f16, f25): eyebrow above a 32 pt display title, optional trailing controls.
struct RootHeader<Trailing: View>: View {
    var eyebrow: String?
    let title: String
    var identifier: String
    @ViewBuilder let trailing: () -> Trailing

    init(eyebrow: String? = nil, title: String, identifier: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.eyebrow = eyebrow
        self.title = title
        self.identifier = identifier
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let eyebrow {
                    Eyebrow(eyebrow).accessibilityIdentifier("\(identifier).eyebrow")
                }
                Text(title)
                    .textStyle(.display32)
                    .foregroundStyle(Color.ms.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(identifier).title")
            }
            Spacer(minLength: Spacing.sm)
            trailing()
        }
        .padding(.top, Spacing.lg)
    }
}

extension RootHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, identifier: String) {
        self.init(eyebrow: eyebrow, title: title, identifier: identifier) { EmptyView() }
    }
}

/// Pushed screen header (f13): 44 pt back chevron, 24 pt title, optional subtitle and right text action.
struct PushedHeader: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String?
    var identifier: String
    var action: HeaderAction?

    struct HeaderAction {
        let title: String
        let identifier: String
        let perform: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Button {
                    dismiss()
                } label: {
                    IconView(.chevronLeft, size: 24)
                        .foregroundStyle(Color.ms.ink)
                        .frame(width: ControlHeight.md, height: ControlHeight.md)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("\(identifier).back")
                Text(title)
                    .textStyle(.title24)
                    .foregroundStyle(Color.ms.ink)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(identifier).title")
                Spacer(minLength: Spacing.sm)
                if let action {
                    Button(action.title, action: action.perform)
                        .buttonStyle(.ms(.text, size: .small))
                        .accessibilityIdentifier(action.identifier)
                }
            }
            .padding(.leading, -Spacing.sm)
            if let subtitle {
                Text(subtitle)
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .padding(.leading, ControlHeight.md - Spacing.sm + Spacing.xs)
                    .accessibilityIdentifier("\(identifier).subtitle")
            }
        }
        .padding(.top, Spacing.sm)
    }
}

/// A root screen: cream page, custom header, offline banner, 720 pt column, toast host. The system
/// navigation bar is hidden; the header is drawn (PRD §7).
struct RootScreenModifier<Trailing: View>: ViewModifier {
    var eyebrow: String?
    let title: String
    let identifier: String
    let trailing: () -> Trailing

    func body(content: Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                RootHeader(eyebrow: eyebrow, title: title, identifier: identifier, trailing: trailing)
                OfflineBannerHost()
                content
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: PageLayout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ms.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle(title)
        .toastHost()
    }
}

/// A pushed screen: back chevron header, no tab bar, cream page, 720 pt column, toast host.
struct PushedScreenModifier: ViewModifier {
    let title: String
    var subtitle: String?
    let identifier: String
    var action: PushedHeader.HeaderAction?

    func body(content: Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PushedHeader(title: title, subtitle: subtitle, identifier: identifier, action: action)
                OfflineBannerHost()
                content
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: PageLayout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ms.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden()
        .navigationTitle(title)
        .toastHost()
    }
}

extension View {
    /// Lays the view out as a root (tab) screen.
    func rootScreen<Trailing: View>(
        eyebrow: String? = nil,
        title: String,
        identifier: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        modifier(RootScreenModifier(eyebrow: eyebrow, title: title, identifier: identifier, trailing: trailing))
    }

    func rootScreen(eyebrow: String? = nil, title: String, identifier: String) -> some View {
        modifier(RootScreenModifier(eyebrow: eyebrow, title: title, identifier: identifier) { EmptyView() })
    }

    /// Lays the view out as a pushed screen. Add `.pinnedPrimaryBar` for its primary action.
    func pushedScreen(
        title: String,
        subtitle: String? = nil,
        identifier: String,
        action: PushedHeader.HeaderAction? = nil
    ) -> some View {
        modifier(PushedScreenModifier(title: title, subtitle: subtitle, identifier: identifier, action: action))
    }
}

#Preview("Root") {
    NavigationStack {
        Text("Content").rootScreen(eyebrow: "Thursday, October 2", title: "Smile Dental", identifier: "home.header") {
            IconButton(.bell, label: "Alerts") {}
        }
    }
}

#Preview("Pushed") {
    NavigationStack {
        Text("Content")
            .pushedScreen(
                title: "Review invoice",
                subtitle: "Patterson Dental · INV-10092 · $449.00",
                identifier: "invoice",
                action: .init(title: "Edit", identifier: "invoice.edit") {}
            )
            .pinnedPrimaryBar { MSButton("Confirm & receive", isFullWidth: true) {} }
    }
}
