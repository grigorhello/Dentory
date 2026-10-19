import SwiftUI

/// "Opened a new one?" (f13): the template's multi-use products with "1 open · 1 in stock" and Take new; the (i)
/// explains it in a toast. A product Add item brought in is listed with the supplies only.
struct ProcedureBottlesSection: View {
    let viewModel: ProcedureStartViewModel

    var body: some View {
        let bottles = viewModel.templateBottles
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Eyebrow("Opened a new one?")
                    .accessibilityAddTraits(.isHeader)
                IconButton(
                    .info, label: "About Take new", variant: .quiet, size: .small, action: viewModel.explainTakeNew
                )
                .accessibilityIdentifier("procDetail.bottles.info")
            }
            ListCard {
                ForEach(bottles) { bottle in
                    ProcedureBottleRow(
                        bottle: bottle,
                        line: viewModel.line(for: bottle),
                        showsDivider: bottle.id != bottles.last?.id
                    ) {
                        viewModel.toggleTakeNew(bottle.id)
                    }
                }
            }
        }
    }
}
