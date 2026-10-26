import SwiftUI

/// Bottom sheet content (PRD §7, Appendix C): grab handle, 24 pt title, one caption line, fields, the
/// primary button last and full width. Present it with `.msSheet(item:)` or `.msSheet(isPresented:)`. A sheet opened
/// from another sheet's content (New product from Choose product) passes `onBack` for the chevron before its title.
struct MSSheet<Content: View, Primary: View>: View {
    let title: String
    var caption: String?
    var identifier: String
    var onBack: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let primary: () -> Primary

    init(
        _ title: String,
        caption: String? = nil,
        identifier: String,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder primary: @escaping () -> Primary
    ) {
        self.title = title
        self.caption = caption
        self.identifier = identifier
        self.onBack = onBack
        self.content = content
        self.primary = primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    if let onBack {
                        IconButton(.chevronLeft, label: "Back", action: onBack)
                            .padding(.leading, -Spacing.md)
                            .accessibilityIdentifier("\(identifier).back")
                    }
                    Text(title)
                        .textStyle(.title24)
                        .foregroundStyle(Color.ms.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("\(identifier).title")
                }
                if let caption {
                    Text(caption).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                }
            }
            content()
            primary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

extension MSSheet where Primary == EmptyView {
    init(_ title: String, caption: String? = nil, identifier: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title, caption: caption, identifier: identifier, onBack: nil, content: content) { EmptyView() }
    }
}

/// The sheet variant for pickers: a search field on top and a 360 pt scrolling list (Appendix C
/// `addItem`, `pickProduct`, `match`, `addOrder`). The caller filters `items` by `searchText`.
struct SheetList<Item: Identifiable, Row: View, Action: View>: View {
    let title: String
    var identifier: String
    /// A line under the title in the monospaced type, as the invoice line Which product is this? asks about (`match`).
    var code: String?
    @Binding var searchText: String
    var placeholder = "Search products"
    var emptyText = "No products match."
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row
    @ViewBuilder let action: () -> Action

    static var listHeight: CGFloat { PageLayout.sheetListHeight }

    init(
        _ title: String,
        identifier: String,
        code: String? = nil,
        searchText: Binding<String>,
        placeholder: String = "Search products",
        emptyText: String = "No products match.",
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.title = title
        self.identifier = identifier
        self.code = code
        _searchText = searchText
        self.placeholder = placeholder
        self.emptyText = emptyText
        self.items = items
        self.row = row
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .textStyle(.title24)
                    .foregroundStyle(Color.ms.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(identifier).title")
                Spacer(minLength: Spacing.sm)
                action()
            }
            if let code {
                Text(code)
                    .textStyle(.mono)
                    .foregroundStyle(Color.ms.textBody)
                    .accessibilityIdentifier("\(identifier).code")
            }
            MSTextField(nil, text: $searchText, placeholder: placeholder, icon: .search)
                .accessibilityIdentifier("\(identifier).search")
            ScrollView {
                ListCard {
                    if items.isEmpty {
                        Text(emptyText)
                            .textStyle(.caption12)
                            .foregroundStyle(Color.ms.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.lg)
                    }
                    ForEach(items) { item in
                        row(item)
                    }
                }
            }
            .frame(height: Self.listHeight)
            .accessibilityIdentifier("\(identifier).list")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

extension SheetList where Action == EmptyView {
    init(
        _ title: String,
        identifier: String,
        code: String? = nil,
        searchText: Binding<String>,
        placeholder: String = "Search products",
        emptyText: String = "No products match.",
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.init(
            title, identifier: identifier, code: code, searchText: searchText, placeholder: placeholder,
            emptyText: emptyText, items: items, row: row
        ) { EmptyView() }
    }
}

/// Wraps sheet content in the drawn look: 36×4 grab handle, cream background, 20 pt top radius,
/// height fitted to the content (up to the screen), keyboard avoiding, swipe down or tap the scrim to close.
/// On iPad the sheet is a centred form sheet at the content width (f36).
struct MSSheetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.ms.line)
                    .frame(width: 36, height: 4)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.md)
                    .accessibilityHidden(true)
                content()
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, Spacing.xl)
            }
            .frame(maxWidth: PageLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                contentHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Spacing.page)
        .presentationBackground(Color.ms.surfacePage)
        .presentationContentInteraction(.scrolls)
    }
}

extension View {
    /// Presents `content` for the item as a Dentory bottom sheet.
    func msSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { item in
            MSSheetContainer { content(item) }
        }
    }

    func msSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            MSSheetContainer(content: content)
        }
    }
}

#Preview("Sheet") {
    @Previewable @State var isPresented = true
    Color.ms.canvas
        .msSheet(isPresented: $isPresented) {
            MSSheet(
                "Adjust inventory",
                caption: "System estimate 54 cartridges. A reason is recorded in history.",
                identifier: "adjust"
            ) {
                MSTextField("Actual quantity", text: .constant("52"), suffix: "cartridges", keyboard: .numberPad)
            } primary: {
                MSButton("Save adjustment", isFullWidth: true) { isPresented = false }
            }
        }
}
