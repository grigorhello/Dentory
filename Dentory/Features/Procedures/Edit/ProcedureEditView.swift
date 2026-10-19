import SwiftUI

/// Edit procedure (f15), and New procedure from "+ Procedure": the name, "DEFAULT SUPPLIES" with steppers, X and
/// Add item, the note, and Delete procedure for a template that exists. Save in the header goes back to Procedures
/// with "Procedure saved"; the back chevron leaves without saving. Admin only: Procedures shows the way in to Admin.
struct ProcedureEditView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProcedureEditViewModel

    init(templateID: UUID?, session: Session, dependencies: AppDependencies) {
        _viewModel = State(
            initialValue: dependencies.makeProcedureEditViewModel(templateID: templateID, session: session)
        )
    }

    var body: some View {
        content
            .pushedScreen(
                title: viewModel.title,
                identifier: "procEdit",
                action: .init(
                    title: "Save", identifier: "procEdit.save", variant: .primary, isLoading: viewModel.isSaving,
                    isDisabled: !viewModel.canSave, perform: save
                )
            )
            .task { await viewModel.load() }
            .onChange(of: viewModel.outcome) { _, outcome in
                guard let outcome else { return }
                dependencies.toasts.show(outcome.title, detail: outcome.detail)
                dismiss()
            }
            .onChange(of: viewModel.generalError) { _, error in
                guard let error else { return }
                dependencies.toasts.show(error.userMessage)
                viewModel.clearGeneralError()
            }
            .msSheet(item: $viewModel.sheet) { sheet in
                switch sheet {
                case .addItem:
                    AddProcedureItemSheet(picker: viewModel)
                case .delete:
                    DeleteProcedureSheet(viewModel: viewModel)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loaded:
            MSTextField(
                "Procedure name", text: $viewModel.name, identifier: "procEdit.name", placeholder: "e.g. Root canal",
                error: viewModel.nameError
            )
            ProcedureDefaultsSection(viewModel: viewModel)
            Text(ProcedureEditViewModel.note)
                .textStyle(.caption12)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("procEdit.note")
            if !viewModel.isNew {
                deleteButton
            }
        case .failed(let error):
            Notice(error.userMessage, tone: .danger)
        case .loading:
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("procEdit.loading")
        }
    }

    /// "Delete procedure" at the bottom, drawn like Delete product on f20.
    private var deleteButton: some View {
        Button(action: viewModel.askToDelete) {
            HStack(spacing: Spacing.sm) {
                IconView(.trash, size: 16)
                Text("Delete procedure")
            }
        }
        .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
        .disabled(viewModel.isSaving)
        .accessibilityIdentifier("procEdit.delete")
    }

    private func save() {
        Task { await viewModel.save() }
    }
}

#Preview("Edit procedure") {
    NavigationStack {
        ProcedureEditView(
            templateID: ProcedureTemplateSummary.demo[0].id, session: .demo, dependencies: .preview()
        )
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo)
}

#Preview("New procedure") {
    NavigationStack {
        ProcedureEditView(templateID: nil, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo)
}
