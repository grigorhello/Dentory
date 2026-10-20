import SwiftUI

/// Procedures (f11 Admin, f12 Staff): the templates with their shortages, the note under them, and the history
/// of past procedures. Admin gets "+ Procedure" in the header and a pencil per template.
struct ProceduresView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var viewModel: ProceduresViewModel
    let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeProceduresViewModel(session: session))
    }

    var body: some View {
        content
            .rootScreen(title: "Procedures", identifier: "proc.header") {
                MSButton("Procedure", icon: .plus, variant: .tertiary, size: .small, action: newTemplate)
                    .accessibilityLabel("New procedure")
                    .accessibilityInputLabels(["Procedure", "New procedure"])
                    .accessibilityIdentifier("proc.addTemplate")
                    .adminOnly()
            }
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: ProcedureRoute.self) { route in
                switch route {
                case .start(let templateID):
                    ProcedureStartView(templateID: templateID, session: session, dependencies: dependencies)
                case .editTemplate(let templateID):
                    ProcedureEditView(templateID: templateID, session: session, dependencies: dependencies)
                case .event:
                    ProcedureRoutePlaceholderView()
                }
            }
    }

    @ViewBuilder private var content: some View {
        if !viewModel.templates.isEmpty {
            ProcedureTemplatesCard(viewModel: viewModel, onEdit: editTemplate)
            Text(viewModel.note)
                .textStyle(.caption12)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("proc.note")
        } else if viewModel.hasNoTemplates {
            EmptyStateView("No procedures yet.")
        } else if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else {
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("proc.loading")
        }
        if !viewModel.history.isEmpty {
            ProcedureHistorySection(viewModel: viewModel)
        }
    }

    private func newTemplate() {
        router.push(ProcedureRoute.editTemplate(nil), on: .procedures)
    }

    private func editTemplate(_ id: UUID) {
        router.push(ProcedureRoute.editTemplate(id), on: .procedures)
    }
}

#Preview("Procedures · Admin") {
    NavigationStack {
        ProceduresView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo)
}

#Preview("Procedures · Staff") {
    NavigationStack {
        ProceduresView(session: .demo(role: .staff), dependencies: .preview(role: .staff))
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo(role: .staff))
}
