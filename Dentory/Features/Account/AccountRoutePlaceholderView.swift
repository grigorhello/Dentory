import SwiftUI

/// A pushed screen that names the ticket bringing the real one.
struct AccountRoutePlaceholderView: View {
    let route: AccountRoute

    var body: some View {
        Text("\(title) arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .pushedScreen(title: title, identifier: identifier)
    }

    private var title: String {
        switch route {
        case .team: "Team"
        case .settings: "Clinic settings"
        case .billing: "Billing"
        }
    }

    /// The PRD Appendix B screen keys.
    private var identifier: String {
        switch route {
        case .team: "team"
        case .settings: "settings"
        case .billing: "billing"
        }
    }
}
