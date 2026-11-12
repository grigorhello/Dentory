import SwiftUI

/// "This photo is hard to read" (MS-163, `receive.check`): why the captured page may not be read well, Retake (or
/// Choose another for a file) to capture it again, and Use anyway to send it on as it is. Swiping it away drops the
/// pages.
struct ReceiveCheckSheet: View {
    let check: ReceiveCheck
    let viewModel: ReceiveViewModel

    var body: some View {
        MSSheet(check.title, identifier: "receive.check") {
            Text(check.message)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("receive.check.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(check.retakeTitle, isFullWidth: true, action: viewModel.retake)
                    .accessibilityIdentifier("receive.check.retake")
                MSButton(ReceiveCheck.useAnywayTitle, variant: .text, isFullWidth: true, action: viewModel.useAnyway)
                    .accessibilityIdentifier("receive.check.useAnyway")
            }
        }
    }
}
