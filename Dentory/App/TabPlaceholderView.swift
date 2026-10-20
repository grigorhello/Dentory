import SwiftUI

/// A tab's stand-in when no session is in the environment (previews of the shell); every tab has its real screen
/// once signed in.
struct TabPlaceholderView: View {
    let tab: AppTab

    var body: some View {
        Text("\(tab.title) arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .accessibilityIdentifier("\(tab.accessibilityIdentifier).placeholder")
            .rootScreen(title: tab.title, identifier: "\(tab.accessibilityIdentifier).header")
    }
}
