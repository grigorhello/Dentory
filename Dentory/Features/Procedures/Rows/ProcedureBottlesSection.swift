import SwiftUI

/// "Opened a new one?" (f13, and Edit usage): the multi-use products with their line and Take new; the (i) explains
/// it in a toast. Adjust, then start lists the template's products; Edit usage the recorded ones.
struct ProcedureBottlesSection: View {
    let lines: [ProcedureBottleLine]
    let onToggle: (UUID) -> Void
    let onExplain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Eyebrow("Opened a new one?")
                    .accessibilityAddTraits(.isHeader)
                IconButton(.info, label: "About Take new", variant: .quiet, size: .small, action: onExplain)
                    .accessibilityIdentifier("procDetail.bottles.info")
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
