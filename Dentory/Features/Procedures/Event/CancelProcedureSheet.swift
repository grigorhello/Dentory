import SwiftUI

/// "Cancel {name}?" (Appendix C `cancelProcedure`): what goes back to stock, the required note, who it is recorded
/// under, a danger "Cancel procedure" that waits for the note, and Keep. A refusal shows here, above the buttons.
struct CancelProcedureSheet: View {
    @Bindable var viewModel: ProcedureEventViewModel

    var body: some View {
        MSSheet(viewModel.cancelTitle, identifier: "cancelProcedure") {
            Notice(viewModel.cancelWarning, tone: .warning)
                .accessibilityIdentifier("cancelProcedure.warning")
            MSTextField(
                "Why is it cancelled?", text: $viewModel.cancelNote, identifier: "cancelProcedure.note",
                placeholder: "e.g. Logged by mistake, patient cancelled"
            )
            Text("Recorded in Activity with your name.")
                .textStyle(.caption12)
                .foregroundStyle(Color.ms.textSecondary)
            if let error = viewModel.cancelError {
                Notice(error, tone: .danger)
                    .accessibilityIdentifier("cancelProcedure.error")
            }
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    "Cancel procedure", variant: .danger, isFullWidth: true, isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canConfirmCancel, action: cancel
                )
                .accessibilityIdentifier("cancelProcedure.confirm")
                MSButton("Keep", variant: .text, isFullWidth: true, action: viewModel.keep)
                    .accessibilityIdentifier("cancelProcedure.keep")
            }
        }
    }

    private func cancel() {
        Task { await viewModel.cancelProcedure() }
    }
}
