import SwiftUI

/// One template (f11, f12): the name, the shortage line only when something is short, "12 items", and for Admin
/// the pencil that edits its defaults. Tapping the row opens Adjust, then start. At the accessibility text sizes
/// "12 items" goes under the name, which would otherwise break mid-word beside it ("Cleani / ng", MS-149).
struct ProcedureTemplateRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let template: ProcedureTemplateSummary
    let itemsText: String
    let shortage: ProceduresViewModel.Shortage?
    let showsDivider: Bool
    let onEdit: () -> Void

    private var identifier: String { "proc.template[\(template.id.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
                NavigationLink(value: ProcedureRoute.start(templateID: template.id)) {
                    AnyLayout.row(stacked: dynamicTypeSize.isAccessibilitySize, stackedSpacing: Spacing.xxs) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(template.name)
                                .textStyle(.bodyStrong14)
                                .foregroundStyle(Color.ms.ink)
                            if let shortage {
                                Text(shortage.text)
                                    .textStyle(.caption12)
                                    .foregroundStyle(shortage.tone.foreground)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(itemsText)
                            .textStyle(.caption12)
                            .foregroundStyle(Color.ms.textSecondary)
                    }
                    .padding(.vertical, Spacing.lg + Spacing.xxs)
                    .frame(minHeight: ControlHeight.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier)
                IconButton(.pencil, label: "Edit \(template.name)", variant: .quiet, size: .row, action: onEdit)
                    .accessibilityIdentifier("\(identifier).edit")
                    .adminOnly()
            }
            if showsDivider {
                ListDivider()
            }
        }
    }
}

#Preview("Template rows") {
    NavigationStack {
        ListCard {
            ProcedureTemplateRow(
                template: ProcedureTemplateSummary.demo[0], itemsText: "12 items",
                shortage: .init(text: "1 not available", tone: .danger), showsDivider: true, onEdit: {}
            )
            ProcedureTemplateRow(
                template: ProcedureTemplateSummary.demo[1], itemsText: "7 items", shortage: nil, showsDivider: false,
                onEdit: {}
            )
        }
        .padding(Spacing.page)
        .background(Color.ms.canvas)
    }
    .environment(\.session, Session.demo)
}
