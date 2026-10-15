import SwiftUI

/// Temporary root with the four tabs. MS-103 replaces it with the real app shell.
struct RootView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    TabPlaceholderView(tab: tab)
                        .navigationTitle(tab.title)
                }
                .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                .tag(tab)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
    }
}

#Preview {
    RootView()
}
