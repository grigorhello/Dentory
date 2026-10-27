import SwiftUI

/// Home (f6 Admin, f7 Staff, f36 iPad): what needs me today, in the PRD §6.2 order and nothing else.
struct HomeView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.writeAccess) private var writeAccess
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Account's Sign out ends it (MS-137); the root puts it in the tabs' environment.
    @Environment(SessionStore.self) private var sessionStore: SessionStore?
    @State private var viewModel: HomeViewModel
    let session: Session
    #if DEBUG
    @State private var isCatalogPresented = false
    /// `-catalogSection buttons` as a launch argument opens the catalog at that section, for screenshots.
    private let launchSection = UserDefaults.standard.string(forKey: "catalogSection")
    /// `-shellDemo sheet|list|toast` opens the shell demo and that overlay, for screenshots.
    private let launchDemo = UserDefaults.standard.string(forKey: "shellDemo")
    #endif

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: HomeViewModel(
            repository: dependencies.homeRepository,
            cache: dependencies.cache,
            clinicID: session.clinicID
        ))
    }

    private var formatters: ClinicFormatters { dependencies.formatters(for: session) }

    var body: some View {
        content
            .rootScreen(
                eyebrow: formatters.weekday(dependencies.clock.now),
                title: session.clinicName,
                identifier: "home.header"
            ) {
                HStack(spacing: Spacing.sm) {
                    HomeHeaderButton(
                        icon: .bell, label: "Alerts",
                        showsDot: viewModel.summary?.hasUnseenAlerts == true, identifier: "home.header.bell"
                    ) { router.push(HomeRoute.alerts, on: .home) }
                    HomeHeaderButton(icon: .user, label: "Account", identifier: "home.header.account") {
                        router.push(HomeRoute.account, on: .home)
                    }
                }
            }
            .reloadOnReturn { await viewModel.load() }
            // Like Inventory and To buy, Home reloads after any stock change and whenever its tab is chosen, so the
            // procedure card shows the procedure just started on Procedures and its Edit usage opens that one.
            .onChange(of: dependencies.writes.appliedWrites) { reload() }
            .onChange(of: router.selectedTab) { _, tab in
                if tab == .home { reload() }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .expiring(let window):
                    ExpiringView(window: window, session: session, dependencies: dependencies)
                case .alerts:
                    ActivityView(session: session, dependencies: dependencies)
                case .editUsage(let eventID):
                    ProcedureEventView(
                        eventID: eventID, startsEditing: true, session: session, dependencies: dependencies
                    )
                case .inventoryValue:
                    InventoryValueView(session: session, dependencies: dependencies)
                case .account:
                    if let sessionStore {
                        AccountView(session: session, sessionStore: sessionStore, dependencies: dependencies)
                    }
                case .billing:
                    BillingView(session: session, dependencies: dependencies)
                case .receive:
                    ReceiveView(session: session, dependencies: dependencies)
                }
            }
            .debugHooks(
                isCatalogPresented: debugCatalogBinding, launchSection: debugLaunchSection, onAppear: debugOnAppear
            )
    }

    @ViewBuilder private var content: some View {
        if let notice = HomeNotice(session: session, now: dependencies.clock.now, formatters: formatters) {
            Notice(
                notice.text, tone: notice.kind == .readOnly ? .warning : .info,
                action: notice.showsBilling
                    ? NoticeAction(title: "Billing", identifier: "home.notice.billing") {
                        router.push(HomeRoute.billing, on: .home)
                    }
                    : nil,
                identifier: "home.notice"
            )
        }
        if let summary = viewModel.summary {
            // f6 sets the tiles closer under their eyebrow than the screen's 16 pt rhythm.
            VStack(alignment: .leading, spacing: Spacing.xs + Spacing.xxs) {
                Eyebrow("Needs attention")
                    .accessibilityAddTraits(.isHeader)
                attentionTiles(summary)
            }
            ProcedureCard(
                latest: summary.latestProcedure,
                startedAtText: summary.latestProcedure.map { formatters.dateTime($0.startedAt) } ?? "",
                onStart: { router.select(.procedures) },
                onEditUsage: { id in writeAccess.perform { router.push(HomeRoute.editUsage(eventID: id), on: .home) } }
            )
            valueTiles(summary)
            receiveRow
        } else if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else {
            VStack(spacing: Spacing.md) {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow()
            }
            .accessibilityIdentifier("home.loading")
        }
        #if DEBUG
        shellDemoRow
        #endif
    }

    /// The three tiles share the height of the tallest, as f6 draws them.
    private func attentionTiles(_ summary: HomeSummary) -> some View {
        tilesLayout {
            AttentionTile(count: summary.toBuyCount, label: "To buy", tone: .warning, identifier: "home.tile.toBuy") {
                router.select(.toBuy)
            }
            AttentionTile(
                count: summary.expiringBatchCount, label: "Expiring soon", tone: .danger,
                identifier: "home.tile.expiring"
            ) {
                router.push(HomeRoute.expiring(window: nil), on: .home)
            }
            AttentionTile(
                count: summary.missingExpiryProductCount, label: "Missing expiry", tone: .info,
                identifier: "home.tile.missingExpiry"
            ) {
                router.inventoryFilter = .missingExpiry
                router.select(.inventory)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func valueTiles(_ summary: HomeSummary) -> some View {
        tilesLayout {
            ValueTile(
                label: "Inventory value", value: formatters.wholeMoney(summary.inventoryValue),
                identifier: "home.tile.inventoryValue"
            ) {
                router.push(HomeRoute.inventoryValue, on: .home)
            }
            ValueTile(
                label: "At risk, 90 days", value: formatters.wholeMoney(summary.valueAtRisk90),
                identifier: "home.tile.atRisk"
            ) {
                router.push(HomeRoute.expiring(window: 90), on: .home)
            }
        }
    }

    /// Side by side, or one under the other at the accessibility text sizes, where a tile's label would otherwise
    /// break mid-word (MS-149).
    private var tilesLayout: AnyLayout {
        .row(stacked: dynamicTypeSize.isAccessibilitySize, alignment: .top, stackedSpacing: Spacing.md)
    }

    private var receiveRow: some View {
        // The icon goes over the text at the accessibility text sizes, where beside it "delivery" broke (MS-149).
        let iconAndText = AnyLayout.row(stacked: dynamicTypeSize.isAccessibilitySize, spacing: Spacing.lg)
        return Button {
            writeAccess.perform { router.push(HomeRoute.receive, on: .home) }
        } label: {
            HStack(spacing: Spacing.lg) {
                iconAndText {
                    IconView(.truck, size: 24)
                        .foregroundStyle(Color.ms.ink)
                        .frame(width: ControlHeight.lg, height: ControlHeight.lg)
                        .background(Color.ms.surfacePage, in: Circle())
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Receive delivery").textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink)
                        Text("Photo, PDF or manual. You confirm every line.")
                            .textStyle(.body14)
                            .foregroundStyle(Color.ms.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Spacing.sm)
                IconView(.chevronRight, size: 20).foregroundStyle(Color.ms.textBody)
            }
            .padding(Spacing.lg)
            .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.receive")
        .adminOnly()
    }

    private func reload() {
        Task { await viewModel.load() }
    }

    // MARK: - Debug hooks (catalog and shell demo)

    #if DEBUG
    private var debugCatalogBinding: Binding<Bool> { $isCatalogPresented }
    private var debugLaunchSection: String? { launchSection }
    private func debugOnAppear() {
        if launchSection != nil { isCatalogPresented = true }
        if launchDemo != nil, router.path(for: .home).isEmpty { router.push(ShellDemoRoute.pushed) }
    }

    private var shellDemoRow: some View {
        ListCard {
            NavigationLink(value: ShellDemoRoute.pushed) {
                ListRow(
                    "Shell demo",
                    caption: "A pushed screen with a pinned bar, a sheet and a toast. Long press to open the catalog.",
                    navigates: true,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shell.demo.push")
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.8).onEnded { _ in isCatalogPresented = true })
        }
        .navigationDestination(for: ShellDemoRoute.self) { route in
            ShellDemoPushedView(route: route)
        }
    }
    #else
    private var debugCatalogBinding: Binding<Bool> { .constant(false) }
    private var debugLaunchSection: String? { nil }
    private func debugOnAppear() {}
    #endif
}

private extension View {
    /// Debug builds present the design-system catalog; release builds add nothing.
    func debugHooks(
        isCatalogPresented: Binding<Bool>, launchSection: String?, onAppear: @escaping () -> Void
    ) -> some View {
        #if DEBUG
        return self
            .onAppear(perform: onAppear)
            .sheet(isPresented: isCatalogPresented) {
                NavigationStack {
                    DesignSystemCatalogView(initialSection: launchSection)
                }
            }
        #else
        return self
        #endif
    }
}

#Preview("Home · Admin") {
    NavigationStack {
        HomeView(session: .demo, dependencies: .preview())
    }
    .environment(AppRouter())
}
