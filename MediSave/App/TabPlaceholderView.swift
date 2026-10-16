import SwiftUI

/// Temporary tab content in the real shell until each feature ticket brings its screen (MS-114, MS-115,
/// MS-122, MS-126). Home shows the date eyebrow and clinic name of f6. In Debug builds a long press on
/// the Home title opens the design system catalog and a row opens the shell demo.
struct TabPlaceholderView: View {
    @Environment(\.session) private var session
    @Environment(\.appDependencies) private var dependencies
    let tab: AppTab
    #if DEBUG
    @State private var isCatalogPresented = false
    /// `-catalogSection buttons` as a launch argument opens the catalog at that section, for screenshots.
    private let launchSection = UserDefaults.standard.string(forKey: "catalogSection")
    #endif

    var body: some View {
        content
            .rootScreen(eyebrow: eyebrow, title: title, identifier: "\(tab.accessibilityIdentifier).header")
            #if DEBUG
            .onAppear {
                if tab == .home, launchSection != nil { isCatalogPresented = true }
            }
            .sheet(isPresented: $isCatalogPresented) {
                NavigationStack {
                    DesignSystemCatalogView(initialSection: launchSection)
                }
            }
            .navigationDestination(for: ShellDemoRoute.self) { route in
                ShellDemoPushedView(route: route)
            }
            #endif
    }

    @ViewBuilder private var content: some View {
        Text("\(tab.title) arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .accessibilityIdentifier("\(tab.accessibilityIdentifier).placeholder")
            #if DEBUG
            .onLongPressGesture {
                if tab == .home { isCatalogPresented = true }
            }
            #endif
        #if DEBUG
        ListCard {
            NavigationLink(value: ShellDemoRoute.pushed) {
                ListRow(
                    "Shell demo",
                    caption: "A pushed screen with a pinned bar, a sheet and a toast",
                    navigates: true,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shell.demo.push")
        }
        #endif
    }

    private var eyebrow: String? {
        guard tab == .home, let session else { return nil }
        let formatters = dependencies.formatters(for: session)
        return formatters.weekday(dependencies.clock.now)
    }

    private var title: String {
        tab == .home ? (session?.clinicName ?? tab.title) : tab.title
    }
}
