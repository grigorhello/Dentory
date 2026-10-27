import SwiftUI

/// Root screen header (f6, f16, f25): eyebrow above a 32 pt display title, optional trailing controls. The scaffold
/// places it 8 pt under the status bar, as the frames draw it under their status area.
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
        if eyebrow == nil {
            // A title alone is one word or two of the app's own (Inventory, Procedures): where it does not fit on one
            // line beside its control at a large text size, the control moves under it rather than break the word
            // (MS-149).
            ViewThatFits(in: .horizontal) {
                row
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    titleStack
                    trailing()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            // Home's clinic name wraps between its words beside the buttons.
            row
        }
    }

    private var row: some View {
        // Home's buttons sit level with the bottom of its eyebrow and title (f6); a title alone is centred on its
        // control, Count stock or + Procedure (f11, f16).
        HStack(alignment: eyebrow == nil ? .center : .bottom, spacing: Spacing.md) {
            titleStack
            Spacer(minLength: Spacing.sm)
            // Beside a title alone the control is a small button: its 44 pt frame reaches past the title's line
            // instead of lowering it (f11 and f16 centre the 36 pt button on the title).
            trailing()
                .padding(.vertical, eyebrow == nil ? -(ControlHeight.hitTarget - ControlHeight.sm) / 2 : 0)
        }
    }

    private var titleStack: some View {
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
    }
}

extension RootHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, identifier: String) {
        self.init(eyebrow: eyebrow, title: title, identifier: identifier) { EmptyView() }
    }
}

/// How a pushed screen's header row reads its text: the 20 pt bold title (f13), or a 14 pt secondary context line
/// such as "Anesthetic · 1 box = 50 cartridges" when the screen's own title sits in the content (f20).
nonisolated enum PushedHeaderStyle: Sendable {
    case title
    case context
}

/// Pushed screen header (f13): 44 pt back chevron, the 20 pt bold title the frames draw (Inter 700, where PRD §7 says
/// 24), optional subtitle and a right action: a text button ("Edit", f20) or a small primary one ("Save", f15); or a
/// "…" menu (Review invoice's Discard invoice). The scaffold places its row 6 pt under the status bar.
struct PushedHeader: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String?
    var identifier: String
    /// The subtitle's own Appendix B id ("invoice.header"); `{identifier}.subtitle` otherwise.
    var subtitleIdentifier: String?
    var action: HeaderAction?
    /// The "…" menu at the end of the row.
    var menu: IconMenu?
    var style: PushedHeaderStyle = .title
    /// Runs on Back in place of leaving, for a screen that asks before discarding changes (Clinic settings).
    var onBack: (() -> Void)?

    struct HeaderAction {
        let title: String
        let identifier: String
        var variant: MSButtonVariant = .text
        /// A leading icon, as Team's "Invite" (f31).
        var icon: Icon?
        var isLoading = false
        var isDisabled = false
        let perform: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    IconView(.chevronLeft, size: 24)
                        .foregroundStyle(Color.ms.ink)
                        .frame(width: ControlHeight.md, height: ControlHeight.md)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("\(identifier).back")
                if style == .context {
                    // One line as f20 draws it; a second rather than a cut-off unit on a narrow phone or at a large
                    // text size.
                    Text(title)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.textSecondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("\(identifier).context")
                } else {
                    // A long title, a procedure's own name, takes more lines rather than lose its end (MS-149).
                    Text(title)
                        .textStyle(.title20)
                        .foregroundStyle(Color.ms.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("\(identifier).title")
                }
                Spacer(minLength: Spacing.sm)
                if let action {
                    MSButton(
                        action.title, icon: action.icon, variant: action.variant, size: .small,
                        isLoading: action.isLoading, isDisabled: action.isDisabled, action: action.perform
                    )
                    .accessibilityIdentifier(action.identifier)
                }
                if let menu {
                    menu
                }
            }
            .padding(.leading, -Spacing.sm)
            if let subtitle {
                Text(subtitle)
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .padding(.leading, ControlHeight.md - Spacing.sm + Spacing.xs)
                    .accessibilityIdentifier(subtitleIdentifier ?? "\(identifier).subtitle")
            }
        }
    }
}

/// A root screen: cream page, custom header, offline banner, 720 pt column. The system
/// navigation bar is hidden; the header is drawn (PRD §7) and stays pinned while the content scrolls under it, with
/// the screen's `pinned` controls under it, such as Inventory's search field and chips (f16-2).
struct RootScreenModifier<Trailing: View, Pinned: View>: ViewModifier {
    var eyebrow: String?
    let title: String
    let identifier: String
    let trailing: () -> Trailing
    /// The controls that stay under the header while the content scrolls; none when nil.
    var pinned: Pinned?

    func body(content: Content) -> some View {
        ScreenScaffold(headerGap: PageLayout.rootHeaderGap, pinned: pinned) {
            RootHeader(eyebrow: eyebrow, title: title, identifier: identifier, trailing: trailing)
        } content: {
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle(title)
    }
}

/// A pushed screen: back chevron header, cream page, 720 pt column. The header stays pinned while the content
/// scrolls under it (f13-2, f15-2, f20-2), so a header action such as Save is always in reach, and so do the screen's
/// `pinned` controls, such as Activity's segments and chips (f09-2). The tab bar hides because the tab's path is no
/// longer empty (`AppTabsView`).
struct PushedScreenModifier<Pinned: View>: ViewModifier {
    let title: String
    var subtitle: String?
    let identifier: String
    var subtitleIdentifier: String?
    var action: PushedHeader.HeaderAction?
    var menu: IconMenu?
    var style: PushedHeaderStyle = .title
    var onBack: (() -> Void)?
    /// The controls that stay under the header while the content scrolls; none when nil.
    var pinned: Pinned?

    func body(content: Content) -> some View {
        ScreenScaffold(headerGap: PageLayout.pushedHeaderGap, pinned: pinned) {
            PushedHeader(
                title: title, subtitle: subtitle, identifier: identifier, subtitleIdentifier: subtitleIdentifier,
                action: action, menu: menu, style: style, onBack: onBack
            )
        } content: {
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .navigationTitle(title)
    }
}

/// The page both screen kinds share: the header, the offline banner and the screen's pinned controls at the top,
/// the content in a scroll view under them, both in the 720 pt column on the cream page. The header sits `headerGap`
/// under the status bar, read from the real safe area (`PageLayout.headerInset`), so it lands where the frames draw
/// it and never under the status bar or the Dynamic Island. The banner and the pinned controls follow 12 pt apart, as
/// the frames draw the search field under Inventory's title and Activity's segments under its header (a chip row's
/// 44 pt targets add their 4 pt). At rest the content starts 16 pt under the pinned block, as before anything was
/// pinned; scrolled, it is cut where the frames cut it.
private struct ScreenScaffold<Header: View, Pinned: View, Content: View>: View {
    let headerGap: CGFloat
    let pinned: Pinned?
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header()
                    OfflineBannerHost()
                    if let pinned {
                        pinned
                    }
                }
                .padding(.top, PageLayout.headerInset(gap: headerGap, safeAreaTop: proxy.safeAreaInsets.top))
                .padding(.bottom, cut)
                .contentColumn()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        content()
                    }
                    .padding(.top, Spacing.lg - cut)
                    .padding(.bottom, Spacing.xl)
                    .contentColumn()
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Color.ms.canvas)
    }

    /// How far under the pinned block scrolled content is cut: 8 pt under the header row (f13-2, f20-2), and 4 pt under
    /// pinned controls, as under the chips of f16-2 and f09-2, which keeps a strip of page between a segmented control
    /// and a card of the same colour scrolling under it.
    private var cut: CGFloat {
        pinned == nil ? Spacing.sm : Spacing.xs
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
        modifier(RootScreenModifier<Trailing, EmptyView>(
            eyebrow: eyebrow, title: title, identifier: identifier, trailing: trailing
        ))
    }

    /// Lays the view out as a root screen whose `pinned` controls stay under the header while the content scrolls
    /// (f16-2: Inventory's search field and chips). A header without a control of its own passes `{ EmptyView() }`.
    func rootScreen<Trailing: View, Pinned: View>(
        eyebrow: String? = nil,
        title: String,
        identifier: String,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder pinned: () -> Pinned
    ) -> some View {
        modifier(RootScreenModifier(
            eyebrow: eyebrow, title: title, identifier: identifier, trailing: trailing, pinned: pinned()
        ))
    }

    func rootScreen(eyebrow: String? = nil, title: String, identifier: String) -> some View {
        rootScreen(eyebrow: eyebrow, title: title, identifier: identifier) { EmptyView() }
    }

    /// Lays the view out as a pushed screen. Add `.pinnedPrimaryBar` for its primary action.
    /// `style: .context` reads the title as a secondary line when the content carries the real title (f20).
    /// `onBack` replaces leaving on Back, for a screen that asks before discarding changes. `subtitleIdentifier`
    /// names the subtitle when Appendix B gives it an id of its own. `menu` ends the row with a "…" menu.
    func pushedScreen(
        title: String,
        subtitle: String? = nil,
        identifier: String,
        subtitleIdentifier: String? = nil,
        action: PushedHeader.HeaderAction? = nil,
        menu: IconMenu? = nil,
        style: PushedHeaderStyle = .title,
        onBack: (() -> Void)? = nil
    ) -> some View {
        modifier(PushedScreenModifier<EmptyView>(
            title: title, subtitle: subtitle, identifier: identifier, subtitleIdentifier: subtitleIdentifier,
            action: action, menu: menu, style: style, onBack: onBack
        ))
    }

    /// Lays the view out as a pushed screen whose `pinned` controls stay under the header while the content scrolls
    /// (f09-2: Activity's segments and History's chips). Pass `pinned:` by its label: a bare trailing closure would
    /// also read as `onBack`.
    func pushedScreen<Pinned: View>(
        title: String,
        subtitle: String? = nil,
        identifier: String,
        subtitleIdentifier: String? = nil,
        action: PushedHeader.HeaderAction? = nil,
        menu: IconMenu? = nil,
        style: PushedHeaderStyle = .title,
        onBack: (() -> Void)? = nil,
        @ViewBuilder pinned: () -> Pinned
    ) -> some View {
        modifier(PushedScreenModifier(
            title: title, subtitle: subtitle, identifier: identifier, subtitleIdentifier: subtitleIdentifier,
            action: action, menu: menu, style: style, onBack: onBack, pinned: pinned()
        ))
    }
}

#Preview("Root") {
    NavigationStack {
        Text("Content").rootScreen(eyebrow: "Thursday, October 2", title: "Smile Dental", identifier: "home.header") {
            IconButton(.bell, label: "Alerts") {}
        }
    }
}

#Preview("Root with pinned controls") {
    @Previewable @State var search = ""
    NavigationStack {
        ForEach(1...30, id: \.self) { Text("Row \($0)") }
            .rootScreen(title: "Inventory", identifier: "inv.header") {
                EmptyView()
            } pinned: {
                MSTextField(nil, text: $search, placeholder: "Search products", icon: .search)
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
