import SwiftUI

/// One multi-use product (f13): the name, "1 open · 1 in stock", and Take new, outlined when off and filled blue when
/// on ("Will take 1 from stock · 0 unopened left"). There is no X: the template decides which products appear here.
struct ProcedureBottleRow: View {
    let bottle: ProcedureStartViewModel.Bottle
    let line: String
    let showsDivider: Bool
    let onToggle: () -> Void

    var body: some View {
        ListRow(bottle.item.name, caption: line, showsDivider: showsDivider) {
            MSButton(
                "Take new", variant: bottle.takesNew ? .primary : .tertiary, size: .small, action: onToggle
            )
            .accessibilityAddTraits(bottle.takesNew ? .isSelected : [])
            .accessibilityIdentifier("procDetail.bottle[\(bottle.id.uuidString.lowercased())].takeNew")
        }
    }
}
