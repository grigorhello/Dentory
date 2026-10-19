import SwiftUI

/// "Delete {name}?" (Appendix C `deleteProduct`): what archiving means, a danger button and Keep.
struct DeleteProductSheet: View {
    let title: String
    let message: String
    let isDeleting: Bool
    let onDelete: () -> Void
    let onKeep: () -> Void

    var body: some View {
        MSSheet(title, identifier: "deleteProduct") {
            Text(message)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("deleteProduct.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton("Delete product", variant: .danger, isFullWidth: true, isLoading: isDeleting, action: onDelete)
                    .accessibilityIdentifier("deleteProduct.confirm")
                MSButton("Keep", variant: .text, isFullWidth: true, action: onKeep)
                    .accessibilityIdentifier("deleteProduct.keep")
            }
        }
    }
}

#Preview("Delete product") {
    Color.ms.canvas
        .msSheet(isPresented: .constant(true)) {
            DeleteProductSheet(
                title: "Delete Septocaine 4% 1:100,000?",
                message: "54 cartridges still in stock. The product and its history are archived, not erased. "
                    + "It disappears from Inventory, To buy and procedures.",
                isDeleting: false, onDelete: {}, onKeep: {}
            )
        }
}
