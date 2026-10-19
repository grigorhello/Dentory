import SwiftUI

/// A past procedure until MS-124 brings its screen: a pushed screen that names the ticket.
struct ProcedureRoutePlaceholderView: View {
    var body: some View {
        Text("Procedure arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .pushedScreen(title: "Procedure", identifier: "procDetail")
    }
}
