import SwiftUI

/// The templates in one card (f11): each opens Adjust, then start; Admin edits one with its pencil.
struct ProcedureTemplatesCard: View {
    let viewModel: ProceduresViewModel
    let onEdit: (UUID) -> Void

    var body: some View {
        let templates = viewModel.templates
        ListCard {
            ForEach(templates) { template in
                ProcedureTemplateRow(
                    template: template,
                    itemsText: viewModel.itemsText(template.itemCount),
                    shortage: viewModel.shortage(for: template),
                    showsDivider: template.id != templates.last?.id,
                    onEdit: { onEdit(template.id) }
                )
            }
        }
    }
}
