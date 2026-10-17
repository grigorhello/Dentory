import SwiftUI

/// Temporary tab content in the real shell until each feature ticket brings its screen (MS-115, MS-122,
/// MS-126). Home is real (MS-114).
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
