import SwiftUI

/// A past procedure (f14), from the Procedures history or Home's Edit usage: the green banner and "Supplies used"
/// with Edit usage and Cancel procedure pinned below; in editing mode the steppers, Add item and Take new with Save
/// changes and Discard; a cancelled procedure shows why and offers nothing.
struct ProcedureEventView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProcedureEventViewModel

    init(eventID: UUID, startsEditing: Bool = false, session: Session, dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeProcedureEventViewModel(
            eventID: eventID, startsEditing: startsEditing, session: session
        ))
    }

    var body: some View {
        content
            .pushedScreen(title: viewModel.title, identifier: "procDetail")
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .task { await viewModel.load() }
            .onChange(of: viewModel.finished) { _, finished in
                guard let finished else { return }
                dependencies.toasts.show(finished.title, detail: finished.detail)
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
            .msSheet(item: $viewModel.sheet) { sheet in
                switch sheet {
                case .addItem:
                    AddProcedureItemSheet(
                        searchText: $viewModel.searchText, products: viewModel.addableProducts,
                        emptyText: viewModel.addItemEmptyText, outOfStockProductID: viewModel.outOfStockProductID,
                        caption: viewModel.addCaption(for:), captionTone: viewModel.addCaptionTone(for:),
                        onAdd: viewModel.add, load: viewModel.loadProducts
                    )
                case .cancel:
                    CancelProcedureSheet(viewModel: viewModel)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loaded:
            if let detail = viewModel.detail {
                loaded(detail)
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

    @ViewBuilder private func loaded(_ detail: ProcedureEventDetail) -> some View {
        if let cancelled = viewModel.cancelledText {
            Notice(cancelled, tone: .warning)
                .accessibilityIdentifier("procDetail.cancelled")
        } else if viewModel.mode == .editing {
            Notice(ProcedureEventViewModel.editingNotice, tone: .info)
                .accessibilityIdentifier("procDetail.editing")
        } else {
            Notice(viewModel.summary, tone: .success)
                .accessibilityIdentifier("procDetail.summary")
        }
        if viewModel.mode == .editing {
            ProcedureUsageEditCard(viewModel: viewModel)
            if !viewModel.bottleLines.isEmpty {
                ProcedureBottlesSection(
                    lines: viewModel.bottleLines, onToggle: viewModel.toggleTakeNew, onExplain: viewModel.explainTakeNew
                )
            }
        } else {
            ProcedureUsageCard(viewModel: viewModel, items: detail.items)
        }
    }

    /// Edit usage and Cancel procedure under the record; Save changes and Discard while editing; nothing once
    /// cancelled.
    @ViewBuilder private var actions: some View {
        if let detail = viewModel.detail, !detail.isCancelled {
            PinnedPrimaryBar {
                VStack(spacing: Spacing.sm) {
                    if viewModel.mode == .editing {
                        MSButton(
                            "Save changes", icon: .check, isFullWidth: true, isLoading: viewModel.isSubmitting,
                            isDisabled: !viewModel.canSave, action: save
                        )
                        .accessibilityIdentifier("procDetail.save")
                        MSButton("Discard", variant: .text, isFullWidth: true, action: viewModel.discard)
                            .accessibilityIdentifier("procDetail.discard")
                    } else {
                        MSButton(
                            "Edit usage", icon: .pencil, variant: .tertiary, isFullWidth: true,
                            action: viewModel.startEditing
                        )
                        .accessibilityIdentifier("procDetail.editUsage")
                        Button(action: viewModel.askToCancel) {
                            Text("Cancel procedure").foregroundStyle(Color.ms.danger)
                        }
                        .buttonStyle(.ms(.text, fullWidth: true))
                        .accessibilityIdentifier("procDetail.cancel")
                    }
                }
            }
        }
    }

    private func save() {
        Task { await viewModel.save() }
    }
}

#Preview("A past procedure") {
    NavigationStack {
        ProcedureEventView(eventID: ProcedureEventSummary.demo[0].id, session: .demo, dependencies: .preview())
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo)
}

#Preview("Editing") {
    NavigationStack {
        ProcedureEventView(
            eventID: ProcedureEventSummary.demo[0].id, startsEditing: true, session: .demo, dependencies: .preview()
        )
    }
    .environment(AppRouter(selectedTab: .procedures))
    .environment(\.session, Session.demo)
}
