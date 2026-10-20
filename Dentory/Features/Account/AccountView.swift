import SwiftUI

/// Account (f29 Admin, f30 Staff), pushed from Home's account button: the user card, Team and the admin's Clinic
/// settings, Billing and Export CSV (a toast says where the export goes), then Help in the in-app browser and Sign out
/// after its confirmation.
struct AccountView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: AccountViewModel
    @State private var showsHelp = false
    private let session: Session
    private let sessionStore: SessionStore

    init(session: Session, sessionStore: SessionStore, dependencies: AppDependencies) {
        self.session = session
        self.sessionStore = sessionStore
        _viewModel = State(
            initialValue: dependencies.makeAccountViewModel(session: session, sessionStore: sessionStore)
        )
    }

    var body: some View {
        content
            .pushedScreen(title: "Account", identifier: "more")
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: AccountRoute.self) { route in
                switch route {
                case .team:
                    TeamView(session: session, sessionStore: sessionStore, dependencies: dependencies)
                case .settings:
                    ClinicSettingsView(session: session, sessionStore: sessionStore, dependencies: dependencies)
                case .billing:
                    BillingView(session: session, dependencies: dependencies)
                }
            }
            .onChange(of: viewModel.message) { _, message in
                guard let message else { return }
                dependencies.toasts.show(message.title, detail: message.detail)
                viewModel.clearMessage()
            }
            .msSheet(isPresented: $viewModel.isConfirmingSignOut) {
                SignOutSheet(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showsHelp) {
                if let url = AccountViewModel.helpCentre {
                    SafariView(url: url) { showsHelp = false }
                        .ignoresSafeArea()
                }
            }
    }

    @ViewBuilder private var content: some View {
        AccountUserCard(initials: viewModel.initials, name: viewModel.name, roleLine: viewModel.roleLine)
        ListCard {
            NavigationLink(value: AccountRoute.team) {
                AccountRow(icon: .users, title: "Team", value: viewModel.teamText, showsDivider: viewModel.isAdmin)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("more.team")
            if viewModel.isAdmin {
                adminRows
            }
        }
        ListCard {
            Button { showsHelp = true } label: {
                AccountRow(icon: .lifeBuoy, title: "Help")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("more.help")
            Button(action: viewModel.askToSignOut) {
                AccountRow(icon: .logOut, title: "Sign out", isDestructive: true, showsDivider: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("more.signOut")
        }
    }

    /// Clinic settings, Billing and Export CSV (f29); Staff do not see them (f30).
    @ViewBuilder private var adminRows: some View {
        NavigationLink(value: AccountRoute.settings) {
            AccountRow(icon: .settings, title: "Clinic settings")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more.settings")
        NavigationLink(value: AccountRoute.billing) {
            AccountRow(icon: .creditCard, title: "Billing")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more.billing")
        Button {
            Task { await viewModel.startExport() }
        } label: {
            AccountRow(icon: .download, title: "Export CSV", showsDivider: false)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more.export")
    }
}

#Preview("Account · Admin") {
    NavigationStack {
        AccountView(
            session: .demo, sessionStore: SessionStore(auth: PreviewAuthService(session: .demo)),
            dependencies: .preview()
        )
    }
}

#Preview("Account · Staff") {
    NavigationStack {
        AccountView(
            session: .demo(role: .staff),
            sessionStore: SessionStore(auth: PreviewAuthService(session: .demo(role: .staff))),
            dependencies: .preview(role: .staff)
        )
    }
}
