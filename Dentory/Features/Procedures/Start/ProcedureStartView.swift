import SwiftUI

/// Adjust, then start (f13, iPad f37): the template's name, the summary, the supplies with steppers and Add item,
/// "Opened a new one?" with Take new, and Start procedure pinned at the bottom. The back chevron leaves without
/// changing anything.
struct ProcedureStartView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProcedureStartViewModel

    init(templateID: UUID, session: Session, dependencies: AppDependencies) {
        _viewModel = State(
            initialValue: dependencies.makeProcedureStartViewModel(templateID: templateID, session: session)
        )
    }

    var body: some View {
        content
            .pushedScreen(title: viewModel.name, identifier: "procDetail")
            .pinnedPrimaryBar {
                MSButton(
                    viewModel.startTitle, icon: .clipboardCheck, isFullWidth: true,
                    isLoading: viewModel.isStarting, isDisabled: !viewModel.canStart, action: start
                )
                .accessibilityIdentifier("procDetail.start")
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.started) { _, started in
                guard let started else { return }
                dependencies.toasts.show(started.title, detail: started.detail)
                dismiss()
            }
            .onChange(of: viewModel.message) { _, message in
                guard let message else { return }
                dependencies.toasts.show(message.title, detail: message.detail)
                viewModel.clearMessage()
            }
            .onChange(of: viewModel.generalError) { _, error in
                guard let error else { return }
                dependencies.toasts.show(error.userMessage)
                viewModel.clearGeneralError()
            }
            .msSheet(item: $viewModel.sheet) { _ in
                AddProcedureItemSheet(
                    searchText: $viewModel.searchText, products: viewModel.addableProducts,
                    emptyText: viewModel.addItemEmptyText, outOfStockProductID: viewModel.outOfStockProductID,
                    caption: viewModel.addCaption(for:), captionTone: viewModel.addCaptionTone(for:),
                    onAdd: viewModel.add, load: viewModel.loadProducts
                )
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loaded:
            Text(viewModel.summary)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("procDetail.summary")
            ProcedureSuppliesCard(viewModel: viewModel)
            if !viewModel.templateBottles.isEmpty {
                ProcedureBottlesSection(
                    lines: viewModel.bottleLines, onToggle: viewModel.toggleTakeNew, onExplain: viewModel.explainTakeNew
                )
            }
        case .failed(let error):
            Notice(error.userMessage, tone: .danger)
        case .loading:
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("procDetail.loading")
        }
    }

    private func start() {
        Task { await viewModel.start() }
    }
}

#Preview("Adjust, then start") {
    NavigationStack {
        ProcedureStartView(
            templateID: ProcedureTemplateSummary.demo[0].id, session: .demo, dependencies: .preview()
        )
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo)
}
