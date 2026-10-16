import SwiftUI

/// One line under the header while the device has no connection (PRD §7 errors). Reading works;
/// MS-108 queues writes.
struct OfflineBanner: View {
    var body: some View {
        Text("No connection. Changes are saved when you're back online.")
            .textStyle(.caption12)
            .foregroundStyle(Color.ms.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.lg)
            .background(Color.ms.warningSoft, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .accessibilityIdentifier("shell.offline")
    }
}

/// Shows the banner when the monitor in `AppDependencies` reports no connection.
struct OfflineBannerHost: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        if !dependencies.networkMonitor.isConnected {
            OfflineBanner()
        }
    }
}

#Preview("Offline") {
    OfflineBanner().padding(Spacing.page).background(Color.ms.canvas)
}
