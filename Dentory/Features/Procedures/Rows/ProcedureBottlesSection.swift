import SwiftUI

/// "Opened a new one?" (f13, and Edit usage): the multi-use products with their line and Take new; the (i) explains
/// it in a toast. Adjust, then start lists the template's products; Edit usage the recorded ones.
struct ProcedureBottlesSection: View {
    let lines: [ProcedureBottleLine]
    let onToggle: (UUID) -> Void
    let onExplain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow("Opened a new one?")
                .accessibilityAddTraits(.isHeader)
                // The (i) sits 6 pt after the eyebrow at 24 pt, as f13-2 draws it, without making the line taller.
                .overlay(alignment: .trailing) {
                    ProcedureBottlesInfoButton(action: onExplain)
                        .alignmentGuide(.trailing) { $0[.leading] - (Spacing.xs + Spacing.xxs) }
                }
            ListCard {
                ForEach(lines) { bottle in
                    ProcedureBottleRow(
                        productID: bottle.id, name: bottle.name, line: bottle.line, takesNew: bottle.takesNew,
                        showsDivider: bottle.id != lines.last?.id
                    ) {
                        onToggle(bottle.id)
                    }
                }
            }
        }
    }
}
