import Foundation
import SwiftUI

/// The composition root: one instance of each shared service, built once in `DentoryApp` (live) or in
/// previews and tests (fakes). Views read it from the environment and hand their view model what it needs.
/// Feature repositories are added here by their own tickets.
struct AppDependencies: Sendable {
    let rpc: RPCCalling
    let auth: AuthServicing
    let clock: Clock
    let networkMonitor: NetworkMonitoring
    /// One toast at a time, shown once at the app level (MS-103).
    let toasts: ToastCenter
    /// Last answers of repository reads, shown while offline (MS-108).
    let cache: ResponseCaching
    /// The door for stock writes: online now, or queued and replayed (MS-108).
    let writes: WriteCoordinator
    let reporter: ErrorReporting
    let homeRepository: HomeRepository
    /// The device's locale; previews and UI tests use en_US so the frames' figures render as drawn.
    var locale: Locale = .current

    /// Formatters for the signed-in clinic.
    func formatters(for session: Session) -> ClinicFormatters {
        ClinicFormatters(
            currency: session.currency,
            timeZone: TimeZone(identifier: session.timeZone) ?? .current,
            locale: locale,
            clock: clock
        )
    }

    @MainActor
    static func live() -> AppDependencies {
        let client = SupabaseClientProvider.makeClient()
        let rpc = SupabaseRPCClient(transport: SupabaseRPCTransport(client: client))
        let clock = SystemClock()
        let networkMonitor = NetworkMonitor()
        let toasts = ToastCenter()
        let reporter = SentryErrorReporter()
        return AppDependencies(
            rpc: rpc,
            auth: SupabaseAuthService(client: client),
            clock: clock,
            networkMonitor: networkMonitor,
            toasts: toasts,
            cache: FileResponseCache(),
            writes: WriteCoordinator(
                rpc: rpc,
                queue: PendingWriteQueue(store: FilePendingWriteStore()),
                networkMonitor: networkMonitor,
                clock: clock,
                reporter: reporter,
                toasts: toasts
            ),
            reporter: reporter,
            homeRepository: SupabaseHomeRepository(client: client)
        )
    }

    /// No network: a demo clinic, a signed-in admin and a fixed moment, for previews and UI tests.
    @MainActor
    static func preview(
        signedIn: Bool = true, isConnected: Bool = true, role: MembershipRole = .admin
    ) -> AppDependencies {
        let rpc = PreviewRPCClient()
        let clock = FixedClock(Session.demoNow)
        let networkMonitor = FixedNetworkMonitor(isConnected: isConnected)
        let toasts = ToastCenter()
        let reporter = NoopErrorReporter()
        return AppDependencies(
            rpc: rpc,
            auth: PreviewAuthService(session: signedIn ? Session.demo(role: role) : nil),
            clock: clock,
            networkMonitor: networkMonitor,
            toasts: toasts,
            cache: InMemoryResponseCache(),
            writes: WriteCoordinator(
                rpc: rpc,
                queue: PendingWriteQueue(store: InMemoryPendingWriteStore()),
                networkMonitor: networkMonitor,
                clock: clock,
                reporter: reporter,
                toasts: toasts
            ),
            reporter: reporter,
            homeRepository: DemoHomeRepository(),
            locale: Locale(identifier: "en_US")
        )
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.preview()
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Preview doubles

extension Session {
    /// October 2, 2026, 9:41 in New York, the moment every frame shows (the frames label it a Thursday; it is a Friday).
    nonisolated static let demoNow = Date(timeIntervalSince1970: 1_790_933_260)

    nonisolated static let demo = demo(role: .admin)

    /// Sarah (Admin) or Michael (Staff) of the demo clinic (MS-109).
    nonisolated static func demo(role: MembershipRole) -> Session {
        Session(
            userID: UUID(uuidString: "00000000-0000-4000-8000-0000000000a1") ?? UUID(),
            email: role == .admin ? "sarah@smiledental.ca" : "michael@smiledental.ca",
            fullName: role == .admin ? "Sarah Mitchell" : "Michael Reyes",
            clinicID: UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID(),
            clinicName: "Smile Dental",
            role: role,
            currency: "USD",
            timeZone: "America/New_York"
        )
    }
}

/// Answers every function with an empty object; feature previews swap in their own fakes.
struct PreviewRPCClient: RPCCalling {
    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        if let empty = try? JSONDecoder.supabase.decode(Result.self, from: Data("{}".utf8)) {
            return empty
        }
        throw AppError.unknown("No preview data for \(function)")
    }
}

/// Signs in the demo clinic's people with the seed password (MS-109); anything else is refused the
/// way Supabase would.
struct PreviewAuthService: AuthServicing {
    var session: Session?
    static let demoPassword = "smiledental"
    static let demoEmails = ["sarah@smiledental.ca", "michael@smiledental.ca"]

    func restore() async throws -> Session? { session }

    func signIn(email: String, password: String) async throws -> Session {
        try await Task.sleep(for: .milliseconds(400))
        guard Self.demoEmails.contains(email.lowercased()) else { throw AppError.unknownEmail }
        guard password == Self.demoPassword else { throw AppError.wrongPassword }
        return .demo
    }

    func signOut() async throws {}
}
