import SwiftUI

/// The card of the segment on screen: lines still to buy with their steppers, or the ordered and received lines
/// as plain rows ("4 ordered Oct 1 · Patterson", "Received Sep 26 · Patterson"), which have no action: deliveries
/// are received from the invoice.
struct ToBuyRows: View {
    @Environment(\.writeAccess) private var writeAccess
    @Bindable var viewModel: ToBuyViewModel

    var body: some View {
        ListCard {
            ForEach(viewModel.rows) { item in
                switch item.status {
                case .toBuy:
                    ToBuyRow(
                        item: item, line: viewModel.line(for: item), isAdmin: viewModel.isAdmin,
                        showsDivider: item.id != viewModel.rows.last?.id,
                        isSelected: $viewModel[isSelected: item.id], quantity: $viewModel[quantityOf: item.id]
                    ) {
                        writeAccess.perform { Task { await viewModel.remove(item.id) } }
                    }
                case .ordered, .received:
                    ListRow(
                        item.name, caption: viewModel.line(for: item), showsDivider: item.id != viewModel.rows.last?.id
                    )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(identifier(for: item))
                }
            }
        }
        // A row swiped open keeps the card's rounded corners (PRD §7 Lists, 12 pt).
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func identifier(for item: ToBuyItem) -> String {
        let kind = item.status == .ordered ? "ordered" : "received"
        return "order.\(kind)[\(item.id.uuidString.lowercased())]"
    }
}
