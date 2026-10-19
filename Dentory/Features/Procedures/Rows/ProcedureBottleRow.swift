import SwiftUI

/// One multi-use product (f13): the name, its line ("1 open · 1 in stock"), and Take new, outlined when off and filled
/// blue when on. There is no X: the template decides which products appear here.
struct ProcedureBottleRow: View {
    let productID: UUID
    let name: String
    let line: String
    let takesNew: Bool
    let showsDivider: Bool
    let onToggle: () -> Void

    var body: some View {
        ListRow(name, caption: line, showsDivider: showsDivider) {
            MSButton("Take new", variant: takesNew ? .primary : .tertiary, size: .small, action: onToggle)
                .accessibilityAddTraits(takesNew ? .isSelected : [])
                .accessibilityIdentifier("procDetail.bottle[\(productID.uuidString.lowercased())].takeNew")
        }
    }
}
