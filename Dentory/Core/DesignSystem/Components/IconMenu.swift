import SwiftUI

/// A square icon-only button that opens a menu of actions anchored to it, as a screen's "…" menu (Review invoice's
/// Discard invoice). Always give it a label: it is what VoiceOver reads.
struct IconMenu: View {
    /// One action of the menu; a destructive one reads in red.
    struct Item: Identifiable {
        let title: String
        let identifier: String
        var isDestructive = false
        let perform: () -> Void

        var id: String { identifier }
    }

    let icon: Icon
    let label: String
    var identifier: String?
    let items: [Item]

    init(_ icon: Icon, label: String, identifier: String? = nil, items: [Item]) {
        self.icon = icon
        self.label = label
        self.identifier = identifier
        self.items = items
    }

    var body: some View {
        Menu {
            ForEach(items) { item in
                Button(item.title, role: item.isDestructive ? .destructive : nil, action: item.perform)
                    .accessibilityIdentifier(item.identifier)
            }
        } label: {
            IconView(icon, size: IconButtonSize.medium.iconSize)
        }
        .menuStyle(.button)
        .buttonStyle(IconButtonStyle(variant: .ghost, size: .medium))
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? "")
    }
}

#Preview("Icon menu") {
    HStack {
        Spacer()
        IconMenu(.ellipsis, label: "More", items: [
            IconMenu.Item(title: "Discard invoice", identifier: "preview.discard", isDestructive: true) {}
        ])
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
