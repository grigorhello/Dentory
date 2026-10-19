import SwiftUI

/// "Delete {name}?" (MS-125): past procedures keep their data; a danger "Delete procedure" and Keep.
struct DeleteProcedureSheet: View {
    let viewModel: ProcedureEditViewModel

    var body: some View {
        MSSheet(viewModel.deleteTitle, identifier: "deleteProcedure") {
            Text(viewModel.deleteMessage)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("deleteProcedure.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    "Delete procedure", variant: .danger, isFullWidth: true, isLoading: viewModel.isDeleting,
                    action: delete
                )
                .accessibilityIdentifier("deleteProcedure.confirm")
                MSButton("Keep", variant: .text, isFullWidth: true, action: viewModel.keep)
                    .accessibilityIdentifier("deleteProcedure.keep")
            }
        }
    }

    private func delete() {
        Task { await viewModel.delete() }
    }
}
